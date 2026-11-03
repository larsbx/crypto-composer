// Issue larsbx/tclmesh#36. This is a DECLARATIVE, UNTRUSTED claim, not a
// decryption primitive, cryptographic proof, runtime gate, or certificate.
// Even a structurally consistent contract always needs independent evidence.
pub const SubsetPolicy = enum {
    unknown,
    fixed_group_only,
    any_q_claimed,
};

pub const KeyCustody = enum {
    unknown,
    evaluator_full_key,
    independent_shares_claimed,
};

pub const ShareVerification = enum {
    unknown,
    signature_only,
    cryptographic_proof_claimed,
    malicious_secure_mpc_claimed,
};

pub const Delivery = enum {
    unknown,
    kernel_plaintext,
    recipient_only_claimed,
    public_with_policy_claimed,
};

pub const FailureBehavior = enum {
    unknown,
    fail_open,
    fail_closed_claimed,
};

// Do not add accepted/verified/production-ready variants to this enum.
// A proper crypto proof checker (future Dep-Proof) is a separate authority.
pub const EvidenceObligation = enum {
    authentic_source_and_binary,
    audited_security_model_and_parameter_profile,
    proven_corruption_and_privacy_bound,
    every_permitted_q_subset,
    independent_key_share_custody,
    correct_partial_or_mpc_transcript_verification,
    authenticated_combination_without_full_key_fallback,
    exact_ciphertext_manifest_epoch_and_recipient_binding,
    atomic_replay_revocation_and_crash_recovery,
    recipient_delivery_and_leakage_budget,
};

pub const PendingEvidence = []const EvidenceObligation;

const pending = [_]EvidenceObligation{
    .authentic_source_and_binary,
    .audited_security_model_and_parameter_profile,
    .proven_corruption_and_privacy_bound,
    .every_permitted_q_subset,
    .independent_key_share_custody,
    .correct_partial_or_mpc_transcript_verification,
    .authenticated_combination_without_full_key_fallback,
    .exact_ciphertext_manifest_epoch_and_recipient_binding,
    .atomic_replay_revocation_and_crash_recovery,
    .recipient_delivery_and_leakage_budget,
};

pub const CheckError = error{
    UnboundSource,
    InvalidQuorum,
    InvalidPrivacyBound,
    InvalidFaultBound,
    InvalidResponseCount,
    InsufficientPrivacyGuarantee,
    TooManyRequiredResponses,
    UnsupportedSubsetPolicy,
    FullKeyCustody,
    UnestablishedCustody,
    UnverifiedContribution,
    PlaintextAtEvaluator,
    UnestablishedDelivery,
    UnsafeFailureBehavior,
};

pub const Assessment = union(enum) {
    rejected: CheckError,
    // This is intentionally the *only* non-rejecting case.
    pending_evidence: PendingEvidence,
};

pub const Contract = struct {
    scheme_id: []const u8,
    implementation_version: []const u8,
    parameter_profile: []const u8,
    source_revision: []const u8,
    // Untrusted purported checksum, not an authenticated source verification.
    source_sha256: ?[32]u8 = null,

    participants: u16,
    release_quorum: u16,
    privacy_corruptions: u16,
    byzantine_faults: u16,
    client_responses: u16,

    subset_policy: SubsetPolicy = .unknown,
    custody: KeyCustody = .unknown,
    share_verification: ShareVerification = .unknown,
    delivery: Delivery = .unknown,
    failure_behavior: FailureBehavior = .unknown,

    /// Reject internally contradictory DECLARED requirements, not bad
    /// cryptographic implementations. A claimed property is not proof of it.
    pub fn checkNecessary(self: *const @This()) CheckError!void {
        if (self.scheme_id.len == 0 or
            self.implementation_version.len == 0 or
            self.parameter_profile.len == 0 or
            self.source_revision.len == 0 or
            self.source_sha256 == null)
        {
            return error.UnboundSource;
        }
        if (self.participants == 0 or
            self.release_quorum == 0 or
            self.release_quorum > self.participants)
        {
            return error.InvalidQuorum;
        }
        if (self.privacy_corruptions >= self.participants) {
            return error.InvalidPrivacyBound;
        }
        if (self.byzantine_faults >= self.participants) {
            return error.InvalidFaultBound;
        }
        if (self.client_responses == 0 or
            self.client_responses > self.participants)
        {
            return error.InvalidResponseCount;
        }

        // Necessary for a q-of-n secrecy claim, not sufficient to establish
        // actual privacy or every-subset reconstruction.
        if (self.privacy_corruptions < self.release_quorum - 1) {
            return error.InsufficientPrivacyGuarantee;
        }
        if (self.client_responses > self.release_quorum) {
            return error.TooManyRequiredResponses;
        }

        if (self.subset_policy != .any_q_claimed) {
            return error.UnsupportedSubsetPolicy;
        }
        switch (self.custody) {
            .independent_shares_claimed => {},
            .evaluator_full_key => return error.FullKeyCustody,
            .unknown => return error.UnestablishedCustody,
        }
        if (self.share_verification != .cryptographic_proof_claimed and
            self.share_verification != .malicious_secure_mpc_claimed)
        {
            return error.UnverifiedContribution;
        }
        switch (self.delivery) {
            .recipient_only_claimed, .public_with_policy_claimed => {},
            .kernel_plaintext => return error.PlaintextAtEvaluator,
            .unknown => return error.UnestablishedDelivery,
        }
        if (self.failure_behavior != .fail_closed_claimed) {
            return error.UnsafeFailureBehavior;
        }
    }

    pub fn assess(self: *const @This()) Assessment {
        self.checkNecessary() catch |err| return .{ .rejected = err };
        // No caller-controlled claim can turn this into a crypto certificate.
        return .{ .pending_evidence = &pending };
    }
};
