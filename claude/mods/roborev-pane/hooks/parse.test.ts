import { expect, test } from 'claude-code/testing'

import { isReviewCommand, jobIdOf, parseReview } from './parse'

const OUTPUT = `## Review Findings

- **Severity**: Low
- **Location**: \`061_french_spacing.ts:91-100\`
- **Problem**: A JSON \`null\` document
  throws on \`node.type\`.
- **Fix**: Return null unless the parsed value is an object.

---

- **Severity**: Medium
- **Location**: docs
- **Problem**: The deploy window is not documented.
- **Fix**: Add one sentence.

## Summary
Titles are stored with no-break spaces.`

test('parses each finding and the summary', () => {
  const { findings, summary } = parseReview(OUTPUT)
  expect(findings).toHaveLength(2)
  expect(findings[0]).toEqual({
    severity: 'Low',
    location: '`061_french_spacing.ts:91-100`',
    problem: 'A JSON `null` document\n  throws on `node.type`.',
    fix: 'Return null unless the parsed value is an object.',
  })
  expect(findings[1]?.severity).toBe('Medium')
  expect(summary).toBe('Titles are stored with no-break spaces.')
})

test('reads a clean review', () => {
  expect(parseReview('No issues found.\n\nSummary: Adds a test.')).toEqual({ findings: [], summary: 'Adds a test.' })
})

test('recognises the review commands and their job id', () => {
  expect(isReviewCommand('roborev wait 734 2>&1 | tail -5')).toBe(true)
  expect(isReviewCommand('roborev list')).toBe(false)
  expect(jobIdOf('roborev wait 734')).toBe(734)
  expect(jobIdOf('roborev show --job 734 --json')).toBe(734)
  expect(jobIdOf('roborev show')).toBeUndefined()
})
