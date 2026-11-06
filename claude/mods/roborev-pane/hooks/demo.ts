import type { Explanation, Review } from '../types'

// `/roborev-pane demo`: a fake review to see the pane without a real roborev job.
export const DEMO_JOB_ID = 0

export const DEMO_REVIEW: Review = {
  jobId: DEMO_JOB_ID,
  branch: 'demo',
  summary: 'Adds a cache in front of the user lookup. This is demo data, not a real review.',
  findings: [
    {
      severity: 'High',
      location: '`src/cache.ts:42`',
      problem: 'The cache key omits the tenant id, so two tenants with the same user id read each other’s profile.',
      fix: 'Build the key from `tenantId` and `userId`.',
    },
    {
      severity: 'Medium',
      location: '`src/cache.ts:58`',
      problem: 'Entries never expire, so a renamed user keeps the old name until the process restarts.',
      fix: 'Set a TTL of a few minutes on each entry.',
    },
    {
      severity: 'Low',
      location: '`docs/cache.md`',
      problem: 'The docs do not mention the new cache.',
      fix: 'Add one paragraph on what is cached and for how long.',
    },
  ],
}

/** Keyed by the finding's index, like the `explanations` atom. */
export const DEMO_EXPLANATIONS: Record<string, Explanation> = {
  '0': {
    problem: 'Two tenants can share a user id. Then one tenant sees the profile of the other tenant.',
    explanation: 'The claim is true. Line 42 uses `userId` alone as the key.',
    recommendation: 'Fix',
    reason: 'This leaks data between tenants.',
  },
  '1': {
    problem: 'A changed user name stays old in the cache. It changes only after a restart.',
    explanation: 'The claim is true. The cache has no TTL and no eviction.',
    recommendation: 'Fix',
    reason: 'Old data shows to users for a long time.',
  },
  '2': {
    problem: 'Readers of the docs do not know about the cache.',
    explanation: 'The claim is true, but the cache is internal.',
    recommendation: 'Dismiss',
    reason: 'No user of the docs needs this detail.',
  },
}
