Revision Memo: Clarifying the Mechanism, Bridge Theorem, and Simulation Architecture

This memo consolidates the main points from our discussion into revision-ready language for the paper. It distinguishes criticisms that should be rejected, criticisms that identify presentation problems, and corrections that should be made directly. The relevant manuscript is cited here:

1. State the central mechanism-mismatch claim more precisely

The paper’s central argument is not merely that deposits are “not literally options.” The substantive claim is that the canonical Diamond–Dybvig marginal withdrawal condition depends on a contractual feature that ordinary demand deposits do not possess.

In the canonical Diamond–Dybvig model:

c
1
	​

>1,

so early withdrawal pays more than the liquidation or storage value of one unit. This above-par payment is part of the optimal liquidity-insurance contract and enters directly into the patient depositor’s withdrawal decision.

Ordinary demand deposits instead redeem at par:

c
1
	​

=1.

They therefore do not reproduce the canonical DD marginal payoff comparison. This is not a cosmetic mismatch. Economic models derive equilibrium behavior from marginal incentives, and the canonical DD depositor’s marginal behavior is not the marginal behavior of an ordinary demand depositor.

Recommended formulation

The canonical Diamond–Dybvig model establishes the existence of a panic equilibrium under a liquidity-insurance contract that pays early withdrawers above par. Ordinary demand deposits do not contain this contractual feature. The resulting mismatch is not merely terminological: it changes the marginal withdrawal condition governing patient depositors. The canonical DD contract therefore does not microfound the marginal behavior of ordinary demand depositors, even though sequential service remains essential in both environments.

This formulation avoids the weaker and more easily dismissed claim that DD is simply “inapplicable.” It identifies exactly what is incorrect for the intended application: the marginal contractual incentive.

2. Separate sequential service from the DD-specific premium mechanism

Sequential service is present in both the canonical DD model and the network model. It is necessary for first-mover incentives and run equilibria. But common sequential service does not make the two marginal mechanisms equivalent.

The distinction is:

Canonical Diamond–Dybvig
Sequential service is present.
The contract pays c
1
	​

>1.
A patient depositor compares an above-par early payment with the continuation payoff.
The early-withdrawal premium directly affects the withdrawal threshold.
Ordinary demand deposits
Sequential service is present.
Early withdrawal pays par.
The depositor compares par recovery now with uncertain recovery later.
The operative incentive is recovery priority, not exercise of an above-par contractual payment.
Network-contagion model
Sequential service remains present.
Depositors infer recovery probabilities from local withdrawal observations.
Earlier withdrawals affect both the available pool and later depositors’ beliefs.
Activation order and network topology help determine which rest point is reached.
Recommended clarification

Sequential service is a shared necessary condition for run equilibria, but it does not uniquely determine marginal withdrawal behavior. The canonical DD model combines sequential service with an above-par liquidity-insurance payment. Ordinary demand deposits combine sequential service with par redemption and uncertain late recovery. The network model is intended to represent the latter environment.

A useful compact phrase is:

Sequential service is common to both models; the marginal payoff and information mechanisms are not.

3. Clarify the purpose of the bridge theorem

The bridge theorem should not be defended primarily as a technically difficult limit result. Its contribution is architectural and interpretive.

Its purpose is to move readers through the following sequence:

canonical DD expected utility→vanishing premium→recovery-probability threshold→network decision rule.

Readers are accustomed to the canonical DD utility-maximization problem. The theorem identifies the decision object that remains when the DD-specific premium approaches zero.

Under shifted CRRA utility, the withdrawal cutoff is

Φ
shift
	​

(ε)=
u(c
2
	​

(ε))−u(0)
u(1+ε)−u(0)
	​

.

As ε→0,

Φ
shift
	​

(ε)→p
∗
(ρ,R).

The significance is not the mathematical difficulty of taking the limit. The significance is that the result formally connects the familiar DD problem to the threshold object used in the network model.

Recommended framing

The bridge theorem is a translation result. It identifies the depositor decision rule that survives when the DD-specific above-par premium vanishes. Its purpose is not to present a technically difficult limit calculation, but to provide a formal handoff from the canonical DD expected-utility problem to the recovery-probability comparison used in the network model.

This language heads off the criticism that the theorem is “only continuity” without pretending the algebra is a moon landing conducted by utility functions.

4. Emphasize that the generalized bridge condition is the operative one

The special-case bridge theorem initially assumes that immediate withdrawal succeeds with certainty:

p
W
	​

=1.

That yields the limiting condition

p
S
	​

≤p
∗
(ρ,R).

In the network model, immediate withdrawal may itself be risky because the agent may be late in the sequential-service queue. The relevant comparison is therefore

p
W
	​

u(c
1
	​

)+(1−p
W
	​

)u(0)≥p
S
	​

u(c
2
	​

)+(1−p
S
	​

)u(0).

This rearranges to

p
S
	​

≤p
W
	​

Φ(c
1
	​

,c
2
	​

,ρ),

and, as ε→0,

p
S
	​

≤p
W
	​

p
∗
(ρ,R).

The generalized expression is the true bridge into the network model.

Recommended emphasis

The special-case threshold p
S
	​

≤p
∗
(ρ,R) applies when immediate withdrawal is certain. Because withdrawal may also fail under sequential service in the network environment, the model uses the generalized bridge condition p
S
	​

≤p
W
	​

p
∗
(ρ,R). This generalized condition, rather than the certainty special case alone, is the decision object transferred into the network simulation.

This should be highlighted near the beginning of the network-model section, not left to perform its crucial labor quietly in a later paragraph.

5. Correct the statement about risk neutrality

The statement identifying ρ=1 with risk neutrality is incorrect.

Under CRRA preferences:

ρ=0 corresponds to linear utility and risk neutrality.
ρ=1 corresponds to log utility.

The corrected interpretation is that under log utility, ρ is fixed at one, so there is no additional risk-aversion parameter to sweep.

Replace language such as

“At ρ=1, assuming risk neutrality…”

With

“At ρ=1, utility is logarithmic. Because the preference parameter is fixed at one, the limiting threshold is determined by R without an additional risk-aversion parameter to vary.”

Or more compactly:

“Under log utility, the threshold is pinned down by R, conditional on the maintained preference specification ρ=1.”

6. Do not say that preferences become irrelevant

The manuscript currently risks overstating the limiting result by suggesting that “the utility function and the premium both become irrelevant.”

The premium disappears from the limiting rule, but preferences do not generally disappear. They are summarized by

p
∗
(ρ,R).

For ρ

=1, the threshold explicitly depends on ρ. At ρ=1, log utility remains the maintained preference specification even though no free preference parameter remains.

Recommended replacement

As the premium vanishes, the premium no longer enters the decision rule. Preferences and the long-asset return are summarized by the fixed threshold p
∗
(ρ,R).

A slightly fuller version:

The limiting result does not make preferences irrelevant. Rather, it compresses the expected-utility comparison into a fixed recovery-probability threshold determined by the maintained preference specification and the return on the long asset.

7. Explain the three simulation exercises as separate parts of the bridge

The computational architecture contains three distinct exercises. Their purposes should be stated before presenting results.

7.1 Diamond–Dybvig core sweep

Question: Does the run probability increase with the DD early-withdrawal premium under the canonical mechanism?

This simulation evaluates the premium comparative static in the model where the premium is operative.

7.2 Finite-agent bridge experiment

Question: Does the limiting withdraw-versus-stay comparison remain stable under finite-agent sequential service and alternative treatments of partial recovery?

This experiment connects the analytic threshold to a finite queueing environment and checks whether the classification depends heavily on how partial payments are treated.

7.3 Network simulations

Question: Once the limiting decision object is placed in a local-information environment, do endogenous withdrawals and failures arise under multiple decision rules?

This exercise tests whether the informational contagion mechanism survives:

the comparative-recovery rule,
the generalized bridge threshold,
and explicit expected utility.
Recommended introductory paragraph

The simulations perform three different tasks. The DD core evaluates the premium comparative static inside the canonical contract. The finite-agent bridge experiment evaluates the limiting withdraw-versus-stay decision under sequential service and partial payments. The network simulations then test whether local-information contagion survives alternative mappings from paired recovery outcomes into withdrawal decisions. The three exercises should therefore be understood as consecutive stages of the transition from the canonical DD model to the network model, not as interchangeable robustness checks.

8. Distinguish the simulation sweeps by design and purpose

The agreement rates across decision rules should not be interpreted as if they came from one homogeneous or globally representative parameter sweep.

There were multiple exercises with different objectives.

Ordinary validation scenarios

These ask whether the bridge threshold reproduces explicit utility in ordinary or representative settings.

The reported 99.5% agreement on matched bank-failure outcomes supports the claim that the bridge rule is a close approximation in these scenarios.

Prespecified monotonicity sweep

This sweep explores comparative statics in neighborhoods of economically important transition regions. It is not intended to sample the parameter space uniformly.

The 96.1% agreement rate should therefore be interpreted as robustness across structured neighborhoods near transition boundaries, not as a universal approximation rate.

Adaptive high-entropy stress test

This exercise is deliberately tuned to find cells with:

uncertain outcomes,
high entropy,
proximity to decision boundaries,
or disagreement among decision rules.

High disagreement in this region is expected. It identifies where the approximation ceases to track explicit expected utility closely.

The disagreement is therefore a result, not a failed robustness check.

Recommended language

The validation, monotonicity, and adaptive stress-test exercises answer different questions. The validation scenarios assess approximation accuracy in ordinary settings. The prespecified monotonicity sweep studies comparative statics in neighborhoods of transition regions. The adaptive stress test deliberately selects high-entropy cells near contested decision boundaries, where disagreement should be greatest. Agreement rates from these exercises should not be interpreted as estimates from a common representative parameter distribution.

9. State the decision-rule robustness claim narrowly

The appropriate conclusion is not that the exact decision rule is irrelevant.

The simulations support the narrower claim that:

local information and sequential service generate endogenous withdrawals under all three rules;
the bridge threshold closely tracks explicit utility in ordinary validation settings;
it preserves most binary failure classifications in the prespecified comparative-statics sweep;
disagreement rises near deliberately selected decision boundaries.
Recommended abstract language

The bridge threshold and explicit-utility rules produce nearly identical failure classifications in ordinary validation scenarios and agree on most outcomes in the prespecified comparative-statics sweep. As expected, disagreement is substantially higher in an adaptive stress test selected to locate high-entropy decision boundaries. The network-contagion result is therefore not an artifact of one decision rule, although the exact rule matters near contested boundaries.

Recommended discussion language

The relevant robustness claim is mechanism robustness, not decision-rule equivalence. Endogenous contagion and bank failure occur under each microfoundation. The bridge approximation closely tracks explicit utility away from contested boundaries but can produce materially different outcomes in high-entropy regions.

10. Explain why differing aggregate failure rates do not contradict high classification agreement

High outcome agreement can coexist with meaningful differences in aggregate failure rates when disagreements are concentrated in structurally sensitive cells.

A relatively small number of decision-rule disagreements can produce large aggregate effects when those disagreements occur near cascade thresholds. In such regions, one depositor’s changed decision can alter subsequent neighborhood signals and trigger a different system-wide path.

This is particularly relevant in a path-dependent network model.

Recommended explanation

High pairwise classification agreement does not imply identical aggregate failure rates. Disagreements concentrated near cascade boundaries can be systemically consequential because an altered early withdrawal changes both the remaining reserve pool and later agents’ local signals. The model therefore permits high overall agreement together with meaningful differences in failure rates in transition regions.

This turns what may look like a contradiction into a substantive feature of the cascade mechanism.

11. Clarify what the simulations establish—and what they do not

The simulations establish results conditional on the model:

the DD premium comparative static;
the finite-agent stability of the bridge classification;
the ability of local observations to generate endogenous contagion;
the robustness of that mechanism across several decision rules;
and the location of regions where the bridge approximation breaks down.

They do not by themselves establish:

empirical realism of the truncated-geometric belief process;
empirical calibration of the network topology;
external validity for actual depositor networks;
superiority over global-games or alternative information models;
or welfare optimality of the proposed policy interventions.
Recommended limitation statement

The computational results establish mechanism and decision-rule robustness conditional on the model. They are not presented as an empirical calibration of actual depositor networks or as external validation of the assumed belief process. Empirical identification of depositor observation networks and belief formation remains a separate task.

This limitation strengthens the paper because it keeps the computational claims matched to what the design actually identifies.

12. Refine the paper’s contribution statement

A defensible contribution statement would combine the mechanism-mismatch result with the bridge architecture.

Suggested version

This paper makes three contributions. First, it identifies a contract-structure mismatch between the canonical Diamond–Dybvig model and ordinary demand deposits: the canonical marginal withdrawal condition depends on an above-par early-payment feature absent from demand-deposit contracts. Second, it derives the limiting recovery-probability decision rule that remains as the DD-specific premium vanishes and generalizes that rule to environments in which immediate withdrawal is also risky. Third, it embeds this decision object in a local-information network with sequential service and shows that endogenous withdrawals and bank failures arise under comparative-recovery, bridge-threshold, and explicit expected-utility rules.

A fourth, more cautious contribution may be added:

The simulations also identify the parameter regions in which the bridge approximation closely tracks explicit utility and the high-entropy boundaries at which the exact decision rule becomes consequential.

13. Revise the interpretation of the network results

The network model should not be described merely as proving that “a cascade model cascades.” Its role is more specific:

it transfers the limiting DD decision object into an ordinary-deposit environment;
it permits both withdrawal and waiting to be risky;
it introduces local rather than global observation;
and it shows that the informational mechanism survives alternative microfoundations.
Recommended formulation

The network simulations do not use the threshold rule as an arbitrary behavioral assumption. The bridge theorem derives the limiting threshold from the familiar DD expected-utility problem, and the generalized condition allows immediate withdrawal to be risky under sequential service. The explicit-utility simulations then test whether the resulting contagion mechanism depends on the threshold approximation. The finding that endogenous withdrawals and failures occur under all three rules establishes mechanism robustness, while the stress test identifies the approximation’s boundary.

14. Suggested revision to the abstract

Diamond and Dybvig’s canonical panic mechanism is derived under a liquidity-insurance contract that pays early withdrawers above par. Ordinary demand deposits redeem at par and therefore do not reproduce the canonical model’s marginal withdrawal condition, even though sequential service remains necessary for run equilibria. We formalize the premium comparative static in a stochastic finite-agent DD environment and derive a bridge result showing that, as the above-par premium vanishes, the depositor’s expected-utility problem reduces to a recovery-probability threshold determined by preferences and the long-asset return. A generalized version allows immediate withdrawal itself to be risky under sequential service. We then embed this decision object in a network model in which depositors infer recovery risk from local withdrawal observations. Endogenous withdrawals and bank failures arise under comparative-recovery, bridge-threshold, and explicit expected-utility rules. The bridge threshold closely tracks explicit utility in ordinary validation scenarios and across most of a prespecified comparative-statics sweep, while disagreement rises in an adaptively selected high-entropy stress test near contested decision boundaries. The results distinguish the canonical above-par mechanism from a local-information recovery mechanism applicable to par-value demand deposits.

15. Suggested roadmap paragraph for the introduction

The paper proceeds in three linked stages. First, we isolate the role of the above-par early-withdrawal payment in the canonical DD model and establish its effect on the marginal withdrawal threshold and run probability. Second, we derive the limiting decision rule as this DD-specific premium approaches zero and evaluate that rule in a finite-agent sequential-service environment with partial payments. Third, we transfer the generalized limiting comparison into a network setting in which depositors observe local withdrawals and form beliefs about recovery risk. This architecture is intended to move from the canonical model familiar to readers toward a model of ordinary par-value demand deposits without replacing expected-utility behavior with an unrelated threshold assumption.

16. Suggested rewrite of the bridge interpretation subsection

The bridge theorem is best understood as a translation between models. In the canonical DD contract, the patient depositor’s decision depends on the above-par early-withdrawal payment, the continuation payoff, and preferences. As the premium ε=c
1
	​

−1 vanishes, the premium no longer enters the limiting decision rule. The expected-utility comparison can instead be represented by a fixed recovery-probability threshold p
∗
(ρ,R). Preferences do not disappear; they are summarized, together with the long-asset return, by the threshold.

The certainty version of the theorem assumes that immediate withdrawal succeeds with probability one. In a finite sequential-service environment, however, immediate withdrawal may also fail. The corresponding generalized condition compares the probability of recovery from waiting with the probability of recovery from withdrawing:

p
S
	​

≤p
W
	​

p
∗
(ρ,R).

This generalized condition is the decision object used in the network model. The bridge therefore does not replace expected utility with an arbitrary behavioral threshold. It expresses the limiting expected-utility comparison in a form that can be carried into an environment with local information, heterogeneous queue risk, and endogenous reserve depletion.

17. Suggested rewrite of the simulation-design subsection

The computational design separates three questions. The DD core simulation asks whether increasing the above-par early-withdrawal payment raises failure risk under the canonical contract. The finite-agent bridge experiment asks whether the limiting withdraw-versus-stay classification remains stable under sequential service and alternative treatments of partial payments. The network simulations ask whether local withdrawal observations generate endogenous contagion under three different decision rules: comparative recovery, the generalized bridge threshold, and explicit expected utility.

The network exercises themselves have different purposes. The common-scenario validation set evaluates approximation accuracy in ordinary settings. The prespecified monotonicity sweep explores comparative statics in neighborhoods of transition regions. The adaptive stress test deliberately selects high-entropy cells near contested decision boundaries to identify where the bridge approximation diverges from explicit utility. Agreement rates across these exercises should therefore not be interpreted as estimates from a common representative parameter distribution.

18. Remaining issues worth revisiting

The points above resolve or narrow several earlier criticisms. A few separate issues may still merit revision.

Belief-model justification

The truncated geometric prior should be presented as a tractable baseline, not as uniquely rational or computationally necessary.

A safer formulation is:

The truncated geometric distribution is a deliberately parsimonious belief model chosen for analytical tractability and computational transparency. It is not claimed to be the unique rational posterior or an empirically estimated depositor belief process.

Observability of network parameters

Network degree is observable only after the relevant depositor observation network has been defined and measured.

Instead of saying the key parameters are simply observable, say:

Reserve ratios and insurance coverage are directly measurable. Depositor-network topology is potentially recoverable from supervisory, transactional, ownership, communication, or affiliation data, though the empirically relevant definition of an observation link remains an identification problem.

Policy claims

Policies such as gates, sequenced redemption windows, or altered disclosure timing should be described as mechanism-implied hypotheses unless accompanied by welfare analysis.

A cautious formulation is:

The model identifies information architecture as a potential intervention margin. Evaluating any particular intervention requires additional analysis of anticipation, welfare, commitment, and the possibility that delayed disclosure suppresses useful information.

19. Final positioning

The strongest version of the paper does not need to claim that Diamond–Dybvig is useless or that the network model replaces the entire bank-run literature.

Its sharper claim is:

Diamond–Dybvig correctly demonstrates fragility under sequential service, but the canonical model’s marginal withdrawal behavior is generated by an above-par contract absent from ordinary demand deposits. The bridge theorem identifies the limiting recovery decision when that contract feature disappears, and the network model studies how this decision propagates when depositors infer recovery risk from local withdrawal behavior.

That is a substantial argument. It preserves what is general in DD, identifies what is contract-specific, and explains why a new marginal mechanism is needed for ordinary deposits. Rather inconveniently for the original roast, that is a real contribution rather than a semantic costume change.