import type { Finding } from '../types'

// roborev's review text: `## Review Findings`, findings as `- **Field**: value` lists
// separated by `---`, then `## Summary`; or `No issues found.` and `Summary: …`.

const field = (block: string, name: string): string => {
  const match = new RegExp(`- \\*\\*${name}\\*\\*:\\s*([\\s\\S]*?)(?=\\n- \\*\\*\\w+\\*\\*:|$)`).exec(block)
  return match?.[1]?.trim() ?? ''
}

export function parseReview(output: string): { findings: Finding[]; summary: string } {
  const text = output.trim()
  if (text.startsWith('No issues found')) {
    return { findings: [], summary: text.replace(/^No issues found\.?\s*(Summary:\s*)?/, '').trim() }
  }
  const [body = '', summary = ''] = text.replace(/^## Review Findings\s*/, '').split(/\n## Summary\s*\n/)
  const findings = body
    .split(/\n-{3,}\n/)
    .map(block => ({
      severity: field(block, 'Severity'),
      location: field(block, 'Location'),
      problem: field(block, 'Problem'),
      fix: field(block, 'Fix'),
    }))
    .filter(finding => finding.severity || finding.problem)
  return { findings, summary: summary.trim() }
}

/** The job id a `roborev wait|show` command names, if any. */
export function jobIdOf(command: string): number | undefined {
  const match = /\broborev\s+(?:wait|show)\b(?:\s+--job)?(?:\s+--json)?\s+(\d+)\b/.exec(command)
  return match ? Number(match[1]) : undefined
}

export const isReviewCommand = (command: string): boolean => /\broborev\s+(?:wait|show)\b/.test(command)
