import { expect, test } from 'claude-code/testing'
import type { On } from 'claude-code'

const PANE_PROPS = {
  title: 'Roborev review',
  isFocused: true,
  bodyColumns: 80,
  placement: 'dock',
  scroll: { offset: 0, bodyRows: 40 },
  view: {},
} as const

// roborev answering `list` and `show` with one finished job carrying `structured`; the pane opens it records.
function stubRoborev(on: On, structured: object): string[] {
  const opened: string[] = []
  on('process.run', async (_, e) => {
    const stdout = e.argv[1] === 'list'
      ? JSON.stringify([{ id: 7, status: 'done' }])
      : JSON.stringify({ job_id: 7, structured_output: structured, job: { branch: 'feat/x', status: 'done' } })
    return { value: { exitCode: 0, stdout, stderr: '' } }
  })
  on('ui.open', async (_, e) => {
    opened.push(e.id)
    return { value: { isPlaced: true } }
  })
  return opened
}

test('the pane stays closed at the end of the turn when another job loaded after the pending one', async ($, on) => {
  const opened = stubRoborev(on, { summary: 'Adds a cache.', verdict: 'fail', findings: [{ severity: 'low', problem: 'P', fix: 'F', location: null }] })
  on('tool.call', async () => ({ result: '' }))
  on('turn.complete', async () => ({ text: '' }))

  await $.command.run({ command: 'roborev-pane', args: 'demo' })
  await $.tool.call({ tool: 'Bash', command: 'roborev show --job 7 --json' })
  await $.turn.complete({ answer: '', durationMs: 1, isAborted: false, turnId: 't1', reason: 'answer' })
  expect(opened).toEqual([])
})

test('a clean review does not open the pane', async ($, on) => {
  const opened = stubRoborev(on, { summary: 'Adds docs.', verdict: 'pass', findings: [] })
  const result = await $.command.run({ command: 'roborev-pane', args: '' })
  expect(opened).toEqual([])
  expect(JSON.stringify(result)).toContain('Roborev job 7: no issues. Adds docs.')
})

test('a review roborev could not run opens the pane with a warning, not "no issues"', async ($, on) => {
  const opened = stubRoborev(on, { summary: 'The diff is missing.', verdict: 'unable_to_review', findings: [] })
  await $.command.run({ command: 'roborev-pane', args: '' })
  expect(opened).toEqual(['roborev'])
  const pane = await $.ui.mount({ plugin: 'roborev-pane', surface: 'terminal', component: 'Pane', requestId: 'roborev', props: PANE_PROPS })
  expect(await pane.find({ type: 'Text', text: /roborev could not review/ })).toBeDefined()
  expect(await pane.find({ type: 'Text', text: /no issues/ })).toBeUndefined()
})

test('demo opens the pane at the end of the next turn and closes it once every finding is settled', async ($, on) => {
  const opened: string[] = []
  const closed: string[] = []
  const submitted: string[] = []
  on('ui.open', async (_, e) => {
    opened.push(e.id)
    return { value: { isPlaced: true } }
  })
  on('ui.close', async (_, e) => {
    closed.push(e.id)
    return { value: undefined }
  })
  on('prompt.submit', async (_, e) => {
    submitted.push(e.text)
    return { value: undefined }
  })
  on('turn.complete', async () => ({ text: 'Summary.' }))

  await $.command.run({ command: 'roborev-pane', args: 'demo' })
  expect(opened).toEqual([])

  await $.turn.complete({ answer: 'Summary.', durationMs: 1, isAborted: false, turnId: 't1', reason: 'answer' })
  expect(opened).toEqual(['roborev'])

  const pane = await $.ui.mount({
    plugin: 'roborev-pane',
    surface: 'terminal',
    component: 'Pane',
    requestId: 'roborev',
    props: PANE_PROPS,
  })
  expect(await pane.find({ type: 'Text', text: /demo · finding 1 of 3/ })).toBeDefined()
  for (const decision of ['Fix', 'Fix', 'Dismiss']) {
    expect(closed).toEqual([])
    await pane.press({ key: `decide-${decision}` })
  }
  expect(closed).toEqual(['roborev'])
  expect(submitted).toEqual([])
})
