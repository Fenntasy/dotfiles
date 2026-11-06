import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Decision, Explanation, Review } from '../types'
import { fromStructured, isReviewCommand, jobIdOf, parseReview } from './parse'
import type { StructuredOutput } from './parse'
import { DEMO_EXPLANATIONS, DEMO_JOB_ID, DEMO_REVIEW } from './demo'

const PANE = 'roborev'
const TITLE = 'Roborev review'
const DECISIONS: Decision[] = ['Fix', 'Dismiss', 'Discuss', 'Skip']

const review = atom({ plugin: 'roborev-pane', key: 'review' } as const, null)
const decisions = atom({ plugin: 'roborev-pane', key: 'decisions' } as const, {})
const explanations = atom({ plugin: 'roborev-pane', key: 'explanations' } as const, {})
const position = atom({ plugin: 'roborev-pane', key: 'position' } as const, 0)
const isRawShown = atom({ plugin: 'roborev-pane', key: 'isRawShown' } as const, false)
const saved = atom({ plugin: 'roborev-pane', key: 'saved' } as const, {})
const isOpenPending = atom({ plugin: 'roborev-pane', key: 'isOpenPending' } as const, false)

const EXPLAIN_DESCRIPTION = `Writes your explanation of each finding of the roborev review shown in the roborev pane.
Call it after you read the code and check each claim, then summarize the findings in your final message.
Write every text field in ASD-STE100 Simplified Technical English: one idea per sentence, 20 words at most per sentence, active voice, approved words, no idioms. Keep code names as they are.
"problem" presents the problem itself, so the person knows what is at stake before your verdict: what goes wrong, when it happens, and what it costs the user or the code. Do not judge the claim here.
"explanation" says whether the claim is true, and what you found in the code to check it.
"recommendation" is your advice; "reason" says why. The person still sees roborev's own text one press away and decides with the pane's buttons.
The pane opens when your turn ends, after your chat summary of the findings.`

const EXPLAIN_SCHEMA = {
  type: 'object',
  required: ['jobId', 'findings'],
  properties: {
    jobId: { type: 'integer', description: 'The roborev job the pane shows' },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['number', 'problem', 'explanation', 'recommendation', 'reason'],
        properties: {
          number: { type: 'integer', description: 'The finding number, from 1' },
          problem: { type: 'string', description: 'What goes wrong, when, and what it costs' },
          explanation: { type: 'string', description: 'Whether the claim is true, and what the code shows' },
          recommendation: { type: 'string', enum: DECISIONS },
          reason: { type: 'string' },
        },
      },
    },
  },
}

type ExplainInput = { jobId: number; findings: (Explanation & { number: number })[] }

// The review of `jobId`, or of the branch's newest finished job; undefined while it runs.
async function fetchReview($: EngineInterface, jobId?: number): Promise<Review | undefined> {
  let id = jobId
  if (id === undefined) {
    const listed = await $.process.run(['roborev', 'list', '--json'])
    if (listed.exitCode !== 0) return undefined
    const jobs: { id: number; status: string }[] = JSON.parse(listed.stdout)
    id = jobs.find(job => job.status === 'done')?.id
    if (id === undefined) return undefined
  }
  const shown = await $.process.run(['roborev', 'show', '--job', String(id), '--json'])
  if (shown.exitCode !== 0) return undefined
  const data: {
    job_id: number
    output?: string
    structured_output?: StructuredOutput
    job?: { branch?: string; status?: string }
  } = JSON.parse(shown.stdout)
  if (data.job?.status !== 'done') return undefined
  // Prefer roborev's structured findings; parse the Markdown text only for jobs that predate them.
  const parsed = data.structured_output ? fromStructured(data.structured_output) : data.output ? parseReview(data.output) : undefined
  if (!parsed) return undefined
  return { jobId: data.job_id, branch: data.job.branch ?? '', ...parsed }
}

// Loads the review; opens the pane only when `isOpened` (the /roborev-pane command).
async function show($: EngineInterface, jobId: number | undefined, isOpened: boolean): Promise<Review | undefined> {
  const fetched = await fetchReview($, jobId)
  if (!fetched) return undefined
  await present($, fetched, isOpened)
  return fetched
}

// Nothing to decide and nothing went wrong: the pane stays closed.
const isClean = (current: Review) => current.findings.length === 0 && !current.unparsed && current.verdict !== 'unable_to_review'

async function present($: EngineInterface, fetched: Review, isOpened: boolean): Promise<void> {
  const previous = await read($, review)
  await update($, review, () => fetched)
  if (previous?.jobId !== fetched.jobId) {
    // Park the walkthrough of the job left behind, and pick up the new job's where it stopped.
    const all = await read($, saved)
    const stash = previous
      ? {
          ...all,
          [String(previous.jobId)]: {
            decisions: await read($, decisions),
            explanations: await read($, explanations),
            position: await read($, position),
          },
        }
      : all
    await update($, saved, () => stash)
    const resumed = stash[String(fetched.jobId)]
    await update($, decisions, () => resumed?.decisions ?? {})
    await update($, explanations, () => resumed?.explanations ?? {})
    await update($, position, () => resumed?.position ?? 0)
    await update($, isRawShown, () => false)
  }
  if (isOpened && !isClean(fetched)) await $.ui.open({ id: PANE, title: TITLE })
}

const severityColor = (severity: string) => (severity === 'Critical' || severity === 'High' ? 'error' : severity === 'Medium' ? 'warning' : 'suggestion')

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const started = await next(e)
    await $.command.register({ name: 'roborev-pane', description: "Show the branch's latest roborev review in a pane; `demo` loads a fake review" })
    await $.tool.register({ name: 'explain', description: EXPLAIN_DESCRIPTION, inputSchema: EXPLAIN_SCHEMA })
    return started
  })

  on('command.run', { command: 'roborev-pane' }, async ($, e) => {
    if (e.args.trim() === 'demo') {
      // Like a real review after `explain`: loaded, explained, and opened when the next turn ends.
      await present($, DEMO_REVIEW, false)
      await update($, decisions, () => ({}))
      await update($, explanations, () => DEMO_EXPLANATIONS)
      await update($, position, () => 0)
      await update($, isOpenPending, () => true)
      return { text: 'Demo review loaded. The pane opens when the next turn ends: send any message.' }
    }
    const shown = await show($, undefined, true)
    if (!shown) return { text: 'No finished roborev review for this branch.' }
    if (isClean(shown)) return { text: `Roborev job ${shown.jobId}: no issues. ${shown.summary}`.trim() }
    return { text: 'Roborev review pane opened.' }
  })

  on('tool.call', { tool: 'Bash' }, async ($, e, next) => {
    const result = await next(e)
    // The pane must never affect the Bash result.
    try {
      if (isReviewCommand(e.command)) await show($, jobIdOf(e.command), false)
    } catch {}
    return result
  })

  // The pane waits for the end of the turn that explained the findings, so the chat summary comes first.
  on('turn.complete', async ($, e, next) => {
    const result = await next(e)
    try {
      if (e.agentId === undefined && (await read($, isOpenPending))) {
        await update($, isOpenPending, () => false)
        const current = await read($, review)
        if (current && !isClean(current)) await $.ui.open({ id: PANE, title: TITLE })
      }
    } catch {}
    return result
  })

  on('tool.call', { tool: /^mcp__roborev-pane__explain$/ }, async ($, e) => {
    const input = e as unknown as ExplainInput
    const current = await read($, review)
    if (!current || current.jobId !== input.jobId) {
      return { result: `The pane shows ${current ? `job ${current.jobId}` : 'no review'}, not job ${input.jobId}. Nothing was written.` }
    }
    if (current.unparsed) {
      return {
        result: `The pane could not parse the findings of job ${input.jobId} and has no decision buttons. Nothing was written. Walk the findings with AskUserQuestion instead.`,
      }
    }
    const inRange = input.findings.filter(({ number }) => number >= 1 && number <= current.findings.length)
    const skipped = input.findings.filter(finding => !inRange.includes(finding)).map(({ number }) => number)
    await update($, explanations, all => {
      const written = { ...all }
      for (const { number, problem, explanation, recommendation, reason } of inRange) {
        written[String(number - 1)] = { problem, explanation, recommendation, reason }
      }
      return written
    })
    await update($, isRawShown, () => false)
    await update($, isOpenPending, () => true)
    const note = skipped.length
      ? ` Skipped finding number(s) ${skipped.join(', ')}: the review has ${current.findings.length} finding(s).`
      : ''
    return {
      result: `Wrote ${inRange.length} explanation(s) into the roborev pane for job ${input.jobId}.${note} The pane opens when this turn ends: summarize the findings in your final message.`,
    }
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text, Button, Markdown } = $.ui.resolve(e)
    const current = await read($, review)
    if (!current) return <Text dimColor>No roborev review loaded. Run /roborev-pane.</Text>
    if (current.unparsed) {
      return (
        <Box flexDirection="column" gap={1}>
          <Text bold>
            Job {current.jobId} · {current.branch} ·{' '}
            <Text color="warning">findings not parsed — roborev's own text</Text>
          </Text>
          <Markdown text={current.unparsed} />
        </Box>
      )
    }
    if (current.findings.length === 0 && current.verdict === 'unable_to_review') {
      return (
        <Box flexDirection="column" gap={1}>
          <Text bold>
            Job {current.jobId} · {current.branch} · <Text color="warning">roborev could not review</Text>
          </Text>
          {current.summary && <Markdown text={current.summary} />}
        </Box>
      )
    }
    if (current.findings.length === 0) {
      return (
        <Box flexDirection="column" gap={1}>
          <Text bold>
            Job {current.jobId} · {current.branch} · no issues
          </Text>
          {current.summary && <Text dimColor>{current.summary}</Text>}
        </Box>
      )
    }

    const chosen = await read($, decisions)
    const explained = await read($, explanations)
    const total = current.findings.length
    const index = Math.min(await read($, position), total - 1)
    const finding = current.findings[index]
    if (!finding) return <Text dimColor>No finding at {index + 1}.</Text>
    const explanation = explained[String(index)]
    const showsRaw = (await read($, isRawShown)) || !explanation
    // Discuss and Skip come back for a re-ask, so only Fix and Dismiss close a finding.
    const isFinal = (decision?: Decision) => decision === 'Fix' || decision === 'Dismiss'
    const decided = chosen[String(index)]
    const decidedCount = Object.values(chosen).filter(isFinal).length

    const goTo = async (target: number) => {
      await update($, position, () => Math.max(0, Math.min(total - 1, target)))
      await update($, isRawShown, () => false)
    }
    const decide = async (decision: Decision) => {
      const all = { ...chosen, [String(index)]: decision }
      await update($, decisions, () => all)
      const nextOpen = current.findings.findIndex((_, other) => other !== index && !isFinal(all[String(other)]))
      if (nextOpen !== -1) await goTo(nextOpen)
      // The demo records decisions in the pane only, so no turn starts.
      if (current.jobId !== DEMO_JOB_ID) {
        await $.prompt.submit({
          text: `Roborev job ${current.jobId}, finding ${index + 1} (${finding.severity}, ${finding.location}): ${decision}`,
        })
      }
      // Every finding is Fix or Dismiss: the walkthrough is over.
      if (current.findings.every((_, other) => isFinal(all[String(other)]))) await $.ui.close({ id: PANE })
    }

    const color = severityColor(finding.severity)
    // A labelled block: the label bold and dim, the body as markdown so `code` is coloured.
    const section = (key: string, label: string, body: string, labelColor?: string) => (
      <Box key={key} flexDirection="column">
        <Text bold dimColor={!labelColor} color={labelColor}>
          {label}
        </Text>
        <Markdown text={body} />
      </Box>
    )

    return (
      <Box flexDirection="column" gap={1}>
        <Box flexDirection="row" gap={1}>
          <Text bold>Job {current.jobId}</Text>
          <Text dimColor>
            {current.branch} · finding {index + 1} of {total} · {decidedCount} decided
          </Text>
        </Box>
        <Box flexDirection="column" gap={1} borderStyle="round" borderColor={color} paddingX={1}>
          <Box flexDirection="row" gap={1}>
            <Text bold backgroundColor={color} color="inverseText">
              {` ${finding.severity.toUpperCase()} `}
            </Text>
            <Markdown text={finding.location} />
          </Box>
          {showsRaw || !explanation ? (
            <Box flexDirection="column" gap={1}>
              {!explanation && <Text dimColor italic>No explanation yet — roborev's own text.</Text>}
              {section('problem', 'Problem', finding.problem)}
              {section('fix', 'Suggested fix', finding.fix)}
              {current.summary ? section('summary', 'Review summary', current.summary) : null}
            </Box>
          ) : (
            <Box flexDirection="column" gap={1}>
              {explanation.problem ? section('problem', 'Problem', explanation.problem) : null}
              {section('explanation', explanation.problem ? 'Is it true?' : 'What it means', explanation.explanation)}
              {section('recommendation', `Recommendation: ${explanation.recommendation}`, explanation.reason, 'success')}
            </Box>
          )}
        </Box>
        {isFinal(decided) ? (
          <Text bold color="success">
            ✓ Decided: {decided}
          </Text>
        ) : (
          <Box flexDirection="row" gap={1}>
            {decided && <Text dimColor>Last: {decided}</Text>}
            {DECISIONS.map(decision => (
              <Button
                key={`decide-${decision}`}
                variant={explanation?.recommendation === decision ? 'primary' : 'secondary'}
                onPress={() => void decide(decision)}
              >
                {decision}
              </Button>
            ))}
          </Box>
        )}
        <Box flexDirection="row" gap={1}>
          <Button key="previous" onPress={() => void goTo(index - 1)}>
            Previous
          </Button>
          <Button key="next" onPress={() => void goTo(index + 1)}>
            Next
          </Button>
          {explanation && (
            <Button key="toggle" onPress={() => void update($, isRawShown, shown => !shown)}>
              {showsRaw ? 'Show explanation' : 'Show roborev text'}
            </Button>
          )}
        </Box>
      </Box>
    )
  })
}
