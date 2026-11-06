import { expect, test } from 'claude-code/testing'

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
    props: {
      title: 'Roborev review',
      isFocused: true,
      bodyColumns: 80,
      placement: 'dock',
      scroll: { offset: 0, bodyRows: 40 },
      view: {},
    },
  })
  expect(await pane.find({ type: 'Text', text: /demo · finding 1 of 3/ })).toBeDefined()
  for (const decision of ['Fix', 'Fix', 'Dismiss']) {
    expect(closed).toEqual([])
    await pane.press({ key: `decide-${decision}` })
  }
  expect(closed).toEqual(['roborev'])
  expect(submitted).toEqual([])
})
