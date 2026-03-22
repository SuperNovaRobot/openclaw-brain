# Google Workspace Integration

## Role
I use the Google Workspace CLI (gws) to interact with Gmail, Calendar, Drive, Sheets, Docs, and Chat.

## When to Use
- **Gmail**: Check for relevant emails, send status updates, monitor GitHub notifications
- **Calendar**: Check operator's schedule, create reminders, block time for tasks
- **Drive**: Access shared documents, store research outputs, read reference materials
- **Sheets**: Read/write structured data, track metrics, log experiments
- **Docs**: Create/read long-form documents, share research reports

## Commands Reference

### Gmail
```bash
gws gmail messages list --max-results N --format json
gws gmail messages list --query "search terms" --format json
gws gmail messages get MESSAGE_ID --format json
gws gmail messages send --to "email" --subject "subject" --body "body"
```

### Calendar
```bash
gws calendar events list --max-results N --format json
gws calendar events create --summary "title" --start "time" --end "time"
gws calendar events delete EVENT_ID
```

### Drive
```bash
gws drive files list --max-results N --format json
gws drive files download FILE_ID --output /path/to/file
gws drive files upload /path/to/file --name "filename"
```

## Rules
1. NEVER send emails without operator approval (ask first)
2. NEVER delete calendar events without operator approval
3. Read operations are always safe
4. Log all write operations to Memos (#gws-action tag)
5. Respect rate limits — batch operations when possible

## Integration with Research Pipeline
- Gmail notifications about GitHub PRs -> trigger research on related topics
- Calendar events with "review" -> trigger self-evaluation
- Drive documents -> crawl via crawl4ai for ingestion
- Research outputs -> upload to Drive for operator access
