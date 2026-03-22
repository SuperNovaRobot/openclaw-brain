#!/usr/bin/env python3
"""
Nova Hand — Ruka hand interface via Dynamixel SDK.

Provides high-level control: open, close, grip, move fingers,
and reads position + torque feedback.
"""

import time
import logging
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass, field

logger = logging.getLogger("nova_hand")

# Dynamixel control table addresses (Protocol 2.0)
ADDR_TORQUE_ENABLE = 64
ADDR_GOAL_POSITION = 116
ADDR_PRESENT_POSITION = 132
ADDR_PRESENT_CURRENT = 126
ADDR_PRESENT_VELOCITY = 128
ADDR_OPERATING_MODE = 11
ADDR_GOAL_CURRENT = 102
ADDR_PROFILE_VELOCITY = 112
ADDR_PROFILE_ACCELERATION = 108

# Operating modes
MODE_CURRENT = 0
MODE_VELOCITY = 1
MODE_POSITION = 3
MODE_EXTENDED_POSITION = 4
MODE_CURRENT_POSITION = 5  # Best for grasping — position control with current limit


@dataclass
class FingerState:
    """State of a single finger/joint."""
    motor_id: int
    position: int = 0          # Dynamixel ticks
    current: int = 0           # mA — proxy for torque
    velocity: int = 0
    at_goal: bool = False


@dataclass
class HandState:
    """Complete hand state."""
    fingers: Dict[str, FingerState] = field(default_factory=dict)
    grip_force_ma: int = 0     # Total grip current
    is_gripping: bool = False
    timestamp: float = 0.0


class RukaHand:
    """Interface to Ruka robotic hand via Dynamixel motors."""

    def __init__(self, port: str = "/dev/ttyUSB0", baudrate: int = 1000000,
                 motor_config: Dict[str, int] = None):
        """
        Args:
            port: Serial port for Dynamixel bus
            baudrate: Bus speed (1Mbps default for Dynamixel)
            motor_config: Mapping of finger names to motor IDs
                e.g. {"thumb": 1, "index": 2, "middle": 3, "ring": 4, "pinky": 5, "wrist": 6}
        """
        self.port = port
        self.baudrate = baudrate
        self.motor_config = motor_config or {}
        self._port_handler = None
        self._packet_handler = None
        self._group_read = None
        self._group_write = None
        self._connected = False

        # Grasp parameters
        self.grip_current_threshold = 150   # mA — object contact detected
        self.max_grip_current = 500         # mA — max squeeze force
        self.open_positions = {}            # Per-finger open position
        self.close_positions = {}           # Per-finger closed position

    def connect(self) -> bool:
        """Connect to Dynamixel bus."""
        try:
            from dynamixel_sdk import PortHandler, PacketHandler, GroupSyncRead, GroupSyncWrite

            self._port_handler = PortHandler(self.port)
            self._packet_handler = PacketHandler(2.0)  # Protocol 2.0

            if not self._port_handler.openPort():
                logger.error(f"Failed to open port {self.port}")
                return False

            if not self._port_handler.setBaudRate(self.baudrate):
                logger.error(f"Failed to set baudrate {self.baudrate}")
                return False

            # Set up bulk read for position + current
            self._group_read = GroupSyncRead(
                self._port_handler, self._packet_handler,
                ADDR_PRESENT_POSITION, 10  # Read 10 bytes: position(4) + velocity(4) + current(2)
            )
            for motor_id in self.motor_config.values():
                self._group_read.addParam(motor_id)

            # Set up bulk write for goal positions
            self._group_write = GroupSyncWrite(
                self._port_handler, self._packet_handler,
                ADDR_GOAL_POSITION, 4
            )

            self._connected = True
            logger.info(f"✅ Connected to Ruka hand on {self.port}")
            return True

        except ImportError:
            logger.error("dynamixel_sdk not installed. Run: pip install dynamixel-sdk")
            return False
        except Exception as e:
            logger.error(f"Connection failed: {e}")
            return False

    def enable_torque(self, enable: bool = True):
        """Enable/disable torque on all motors."""
        for name, motor_id in self.motor_config.items():
            self._write1(motor_id, ADDR_TORQUE_ENABLE, 1 if enable else 0)
        logger.info(f"Torque {'enabled' if enable else 'disabled'}")

    def set_mode(self, mode: int = MODE_CURRENT_POSITION):
        """Set operating mode on all motors. Must disable torque first."""
        self.enable_torque(False)
        for name, motor_id in self.motor_config.items():
            self._write1(motor_id, ADDR_OPERATING_MODE, mode)
        self.enable_torque(True)
        logger.info(f"Operating mode set to {mode}")

    def read_state(self) -> HandState:
        """Read all motor positions and currents. ~1ms for the full hand."""
        state = HandState(timestamp=time.time())

        if not self._connected or self._group_read is None:
            return state

        self._group_read.txRxPacket()

        for name, motor_id in self.motor_config.items():
            pos = self._group_read.getData(motor_id, ADDR_PRESENT_POSITION, 4)
            vel = self._group_read.getData(motor_id, ADDR_PRESENT_VELOCITY, 4)
            cur = self._group_read.getData(motor_id, ADDR_PRESENT_CURRENT, 2)

            # Current is signed 16-bit
            if cur > 32767:
                cur -= 65536

            state.fingers[name] = FingerState(
                motor_id=motor_id,
                position=pos,
                current=cur,
                velocity=vel,
            )

        # Grip detection
        total_current = sum(abs(f.current) for f in state.fingers.values())
        state.grip_force_ma = total_current
        state.is_gripping = total_current > self.grip_current_threshold

        return state

    def move_finger(self, name: str, position: int, speed: int = 100):
        """Move a single finger to position."""
        motor_id = self.motor_config.get(name)
        if motor_id is None:
            logger.warning(f"Unknown finger: {name}")
            return
        if speed > 0:
            self._write4(motor_id, ADDR_PROFILE_VELOCITY, speed)
        self._write4(motor_id, ADDR_GOAL_POSITION, position)

    def open_hand(self, speed: int = 200):
        """Open all fingers to their open positions."""
        for name in self.motor_config:
            pos = self.open_positions.get(name, 0)
            self.move_finger(name, pos, speed)
        logger.info("Hand opening")

    def close_hand(self, speed: int = 100, max_current: int = None):
        """Close all fingers. Stops when torque threshold reached."""
        if max_current is not None:
            for motor_id in self.motor_config.values():
                self._write2(motor_id, ADDR_GOAL_CURRENT, max_current)

        for name in self.motor_config:
            pos = self.close_positions.get(name, 4095)
            self.move_finger(name, pos, speed)
        logger.info("Hand closing")

    def grip_until_contact(self, speed: int = 50, timeout: float = 5.0) -> bool:
        """
        Close fingers slowly until torque threshold detected.
        Returns True if object gripped, False if timeout.
        """
        self.close_hand(speed=speed)
        start = time.time()

        while time.time() - start < timeout:
            state = self.read_state()
            if state.is_gripping:
                # Stop all motors at current position
                for name, finger in state.fingers.items():
                    self.move_finger(name, finger.position, speed=0)
                logger.info(f"✅ Object gripped! Force: {state.grip_force_ma}mA")
                return True
            time.sleep(0.01)  # 100Hz check rate

        logger.warning("Grip timeout — no contact detected")
        return False

    def disconnect(self):
        """Clean shutdown."""
        if self._connected:
            self.enable_torque(False)
            self._port_handler.closePort()
            self._connected = False
            logger.info("Hand disconnected")

    # --- Low-level Dynamixel helpers ---

    def _write1(self, motor_id, addr, value):
        self._packet_handler.write1ByteTxRx(self._port_handler, motor_id, addr, value)

    def _write2(self, motor_id, addr, value):
        self._packet_handler.write2ByteTxRx(self._port_handler, motor_id, addr, value)

    def _write4(self, motor_id, addr, value):
        self._packet_handler.write4ByteTxRx(self._port_handler, motor_id, addr, value)

    def __enter__(self):
        self.connect()
        return self

    def __exit__(self, *args):
        self.disconnect()
