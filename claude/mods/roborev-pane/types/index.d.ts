export type Finding = { severity: string; location: string; problem: string; fix: string };

export type Review = {
  jobId: number;
  branch: string;
  findings: Finding[];
  summary: string;
};

export type Decision = 'Fix' | 'Dismiss' | 'Discuss' | 'Skip';

/**
 * Claude's reading of one finding, in ASD-STE100, after checking the code: the problem itself
 * (what goes wrong, when, what it costs), whether the claim holds, and the advice. `problem` is
 * absent from explanations written before it existed.
 */
export type Explanation = { problem?: string; explanation: string; recommendation: Decision; reason: string };

declare module 'claude-code' {
  interface PluginState {
    'roborev-pane': {
      review: Review | null;
      /** Keyed by the finding's index. */
      decisions: Record<string, Decision>;
      /** Keyed by the finding's index. */
      explanations: Record<string, Explanation>;
      /** The index of the finding on screen. */
      position: number;
      /** Whether the finding on screen shows roborev's own text. */
      isRawShown: boolean;
    };
  }
}
