# frozen_string_literal: true

# ============================================================================
# COMPLIANCE WARNING - GDPR DATA MINIMIZATION
# ============================================================================
# This job enforces GDPR Article 5(1)(c) data minimization requirements.
# Modifications require DPO review. See COMPLIANCE.md Section 4.
#
# Current retention policy: 30 days for session content
# Changing this value requires compliance review and documentation update.
# ============================================================================

# DataRetentionJob enforces the 30-day data retention policy.
# It redacts sensitive content from session iterations while preserving
# metadata and anonymized audit logs for compliance purposes.
#
# This job should be scheduled to run daily via cron or similar.
#
# What gets redacted:
# - SessionIteration: user_response, question_asked, reflected_words
# - JourneySession: pending_question, reflected_words_cache
#
# What is preserved:
# - Session metadata (dates, duration, iteration count, depth scores)
# - Safety audit logs (anonymized - no personal content)
# - Session summaries (user-generated, their choice to keep)
class DataRetentionJob < ApplicationJob
  queue_as :default

  # Retry on transient failures
  retry_on ActiveRecord::Deadlocked, wait: 5.minutes, attempts: 3
  retry_on ActiveRecord::ConnectionNotEstablished, wait: 1.minute, attempts: 5

  def perform
    Rails.logger.info "[DataRetentionJob] Starting 30-day data retention cleanup"

    stats = {
      iterations_redacted: 0,
      sessions_cleaned: 0,
      errors: []
    }

    # Redact session iterations older than 30 days
    stats[:iterations_redacted] = redact_old_iterations

    # Clean up pending questions from old sessions
    stats[:sessions_cleaned] = clean_old_sessions

    # Log completion
    Rails.logger.info "[DataRetentionJob] Completed: #{stats[:iterations_redacted]} iterations redacted, #{stats[:sessions_cleaned]} sessions cleaned"

    # Create audit log entry for the cleanup
    log_cleanup_event(stats)

    stats
  end

  private

  def redact_old_iterations
    count = 0

    SessionIteration.for_cleanup.where.not(user_response: "[REDACTED]").find_each do |iteration|
      iteration.update!(
        user_response: "[REDACTED]",
        question_asked: "[REDACTED]",
        reflected_words: "[REDACTED]"
      )
      count += 1
    rescue StandardError => e
      Rails.logger.error "[DataRetentionJob] Failed to redact iteration #{iteration.id}: #{e.message}"
    end

    count
  end

  def clean_old_sessions
    count = 0

    # Clean pending_question and reflected_words_cache from old sessions
    JourneySession
      .where("created_at < ?", 30.days.ago)
      .where.not(pending_question: nil)
      .or(JourneySession.where("created_at < ?", 30.days.ago).where.not(reflected_words_cache: nil))
      .find_each do |session|
        session.update!(
          pending_question: nil,
          reflected_words_cache: nil
        )
        count += 1
      rescue StandardError => e
        Rails.logger.error "[DataRetentionJob] Failed to clean session #{session.id}: #{e.message}"
      end

    count
  end

  def log_cleanup_event(stats)
    # Find or create a system user for audit purposes, or use the first admin
    # For now, we'll just log to Rails logger since SafetyAuditLog requires a session
    Rails.logger.info "[DataRetentionJob] Audit: iterations_redacted=#{stats[:iterations_redacted]}, sessions_cleaned=#{stats[:sessions_cleaned]}"
  end
end
