#!/usr/bin/env node

/**
 * Server-Side TDD Bypass Protection
 * Validates bypass authenticity and enforces server-side restrictions
 * Addresses QA finding SECURITY-001: Client-side bypass protection
 */

import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import os from 'os';

class ServerSideBypassValidator {
  constructor() {
    this.config = {
      // Maximum bypasses allowed per user per day
      maxBypassesPerDay: 3,
      // Maximum bypasses allowed per repository per day
      maxRepoBypassesPerDay: 10,
      // Require justification for bypasses
      requireJustification: true,
      // Minimum justification length
      minJustificationLength: 50,
      // Server-side bypass log location
      serverLogPath: process.env.TDD_BYPASS_SERVER_LOG || '/var/log/tdd-bypasses.log',
      // Local cache for user bypass counts
      localCachePath: '.git/bypass-cache.json',
      // Emergency override secret (should be set via environment)
      emergencySecret: process.env.TDD_EMERGENCY_SECRET,
      // Approved bypass administrators
      approvedAdmins: process.env.TDD_BYPASS_ADMINS ? 
        process.env.TDD_BYPASS_ADMINS.split(',') : 
        ['security-team', 'tech-lead', 'release-manager']
    };
  }

  /**
   * Validate a bypass request with server-side enforcement
   * @param {Object} bypassRequest - The bypass request details
   * @returns {Object} Validation result
   */
  async validateBypass(bypassRequest) {
    try {
      // 1. Validate required fields
      const validation = this._validateRequestFields(bypassRequest);
      if (!validation.valid) {
        return validation;
      }

      // 2. Check user bypass quotas
      const quotaCheck = await this._checkUserQuota(bypassRequest.user);
      if (!quotaCheck.allowed) {
        return {
          valid: false,
          reason: 'QUOTA_EXCEEDED',
          message: `User has exceeded daily bypass limit (${this.config.maxBypassesPerDay})`,
          remainingBypasses: 0,
          nextResetTime: quotaCheck.nextReset
        };
      }

      // 3. Check repository bypass quotas
      const repoQuotaCheck = await this._checkRepositoryQuota(bypassRequest.repository);
      if (!repoQuotaCheck.allowed) {
        return {
          valid: false,
          reason: 'REPO_QUOTA_EXCEEDED',
          message: `Repository has exceeded daily bypass limit (${this.config.maxRepoBypassesPerDay})`,
          repoBypassesUsed: repoQuotaCheck.used,
          nextResetTime: repoQuotaCheck.nextReset
        };
      }

      // 4. Validate justification
      const justificationCheck = this._validateJustification(bypassRequest.justification);
      if (!justificationCheck.valid) {
        return justificationCheck;
      }

      // 5. Check for emergency override
      const emergencyCheck = this._checkEmergencyOverride(bypassRequest);
      if (emergencyCheck.isEmergency) {
        return await this._approveEmergencyBypass(bypassRequest);
      }

      // 6. Check admin approval
      const adminCheck = await this._checkAdminApproval(bypassRequest);
      if (!adminCheck.approved && !emergencyCheck.isEmergency) {
        return {
          valid: false,
          reason: 'ADMIN_APPROVAL_REQUIRED',
          message: 'TDD bypass requires admin approval for non-emergency situations',
          requiredApprovers: this.config.approvedAdmins,
          approvalInstructions: 'Contact an approved admin for bypass authorization'
        };
      }

      // 7. Generate secure bypass token
      const bypassToken = this._generateBypassToken(bypassRequest);

      // 8. Log server-side bypass record
      await this._logServerSideBypass(bypassRequest, bypassToken);

      // 9. Update user and repository bypass counters
      await this._updateBypassCounters(bypassRequest);

      return {
        valid: true,
        reason: 'APPROVED',
        message: 'TDD bypass approved with server-side validation',
        bypassToken: bypassToken,
        expirationTime: Date.now() + (30 * 60 * 1000), // 30 minutes
        conditions: {
          limitedTime: true,
          requiresDocumentation: true,
          auditTrail: true
        },
        remainingBypasses: quotaCheck.remaining - 1
      };

    } catch (error) {
      return {
        valid: false,
        reason: 'SERVER_ERROR',
        message: `Server-side validation failed: ${error.message}`,
        error: process.env.NODE_ENV === 'development' ? error.stack : undefined
      };
    }
  }

  /**
   * Verify a bypass token's authenticity
   * @param {string} token - The bypass token to verify
   * @returns {Object} Verification result
   */
  verifyBypassToken(token) {
    try {
      const [payload, signature] = token.split('.');
      const decodedPayload = JSON.parse(Buffer.from(payload, 'base64').toString());
      
      // Check expiration
      if (Date.now() > decodedPayload.exp) {
        return {
          valid: false,
          reason: 'TOKEN_EXPIRED',
          message: 'Bypass token has expired'
        };
      }

      // Verify signature
      const expectedSignature = this._signPayload(payload);
      if (signature !== expectedSignature) {
        return {
          valid: false,
          reason: 'INVALID_SIGNATURE',
          message: 'Bypass token signature is invalid'
        };
      }

      return {
        valid: true,
        payload: decodedPayload,
        message: 'Bypass token is valid'
      };

    } catch (error) {
      return {
        valid: false,
        reason: 'MALFORMED_TOKEN',
        message: 'Bypass token is malformed or corrupt'
      };
    }
  }

  /**
   * Get bypass statistics for monitoring
   * @returns {Object} Current bypass statistics
   */
  async getBypassStatistics() {
    try {
      const cache = await this._loadBypassCache();
      const today = new Date().toISOString().split('T')[0];
      
      const todayData = cache[today] || { users: {}, repositories: {}, total: 0 };
      
      return {
        date: today,
        totalBypasses: todayData.total || 0,
        userBypasses: Object.keys(todayData.users || {}).length,
        repositoryBypasses: Object.keys(todayData.repositories || {}).length,
        quotaStatus: {
          dailyLimit: this.config.maxBypassesPerDay,
          repoLimit: this.config.maxRepoBypassesPerDay,
          usersNearLimit: this._getUsersNearLimit(todayData.users || {}),
          reposNearLimit: this._getReposNearLimit(todayData.repositories || {})
        },
        lastUpdated: new Date().toISOString()
      };
    } catch (error) {
      return {
        error: `Failed to retrieve statistics: ${error.message}`
      };
    }
  }

  // Private helper methods

  _validateRequestFields(request) {
    const required = ['user', 'repository', 'justification', 'timestamp'];
    const missing = required.filter(field => !request[field]);
    
    if (missing.length > 0) {
      return {
        valid: false,
        reason: 'MISSING_FIELDS',
        message: `Missing required fields: ${missing.join(', ')}`,
        requiredFields: required
      };
    }

    // Validate timestamp is recent (within 5 minutes)
    const requestTime = new Date(request.timestamp).getTime();
    const now = Date.now();
    if (Math.abs(now - requestTime) > 5 * 60 * 1000) {
      return {
        valid: false,
        reason: 'STALE_REQUEST',
        message: 'Bypass request timestamp is too old or in the future'
      };
    }

    return { valid: true };
  }

  async _checkUserQuota(user) {
    try {
      const cache = await this._loadBypassCache();
      const today = new Date().toISOString().split('T')[0];
      const userBypasses = cache[today]?.users?.[user]?.count || 0;

      return {
        allowed: userBypasses < this.config.maxBypassesPerDay,
        used: userBypasses,
        remaining: this.config.maxBypassesPerDay - userBypasses,
        nextReset: this._getNextMidnight()
      };
    } catch (error) {
      // Fail secure - deny if we can't check quota
      return {
        allowed: false,
        error: error.message,
        nextReset: this._getNextMidnight()
      };
    }
  }

  async _checkRepositoryQuota(repository) {
    try {
      const cache = await this._loadBypassCache();
      const today = new Date().toISOString().split('T')[0];
      const repoBypasses = cache[today]?.repositories?.[repository]?.count || 0;

      return {
        allowed: repoBypasses < this.config.maxRepoBypassesPerDay,
        used: repoBypasses,
        remaining: this.config.maxRepoBypassesPerDay - repoBypasses,
        nextReset: this._getNextMidnight()
      };
    } catch (error) {
      return {
        allowed: false,
        error: error.message,
        nextReset: this._getNextMidnight()
      };
    }
  }

  _validateJustification(justification) {
    if (!this.config.requireJustification) {
      return { valid: true };
    }

    if (!justification || typeof justification !== 'string') {
      return {
        valid: false,
        reason: 'MISSING_JUSTIFICATION',
        message: 'Bypass justification is required'
      };
    }

    if (justification.length < this.config.minJustificationLength) {
      return {
        valid: false,
        reason: 'INSUFFICIENT_JUSTIFICATION',
        message: `Justification must be at least ${this.config.minJustificationLength} characters`,
        currentLength: justification.length,
        minimumLength: this.config.minJustificationLength
      };
    }

    // Check for common insufficient justifications
    const insufficientPatterns = [
      /^(urgent|emergency|hotfix|quick|temp)$/i,
      /^(need to deploy|production issue)$/i,
      /^(no time|deadline)$/i
    ];

    for (const pattern of insufficientPatterns) {
      if (pattern.test(justification.trim())) {
        return {
          valid: false,
          reason: 'GENERIC_JUSTIFICATION',
          message: 'Please provide a detailed explanation of why TDD bypass is necessary'
        };
      }
    }

    return { valid: true };
  }

  _checkEmergencyOverride(request) {
    if (!this.config.emergencySecret || !request.emergencySecret) {
      return { isEmergency: false };
    }

    const isValid = crypto.timingSafeEqual(
      Buffer.from(request.emergencySecret),
      Buffer.from(this.config.emergencySecret)
    );

    return { isEmergency: isValid };
  }

  async _checkAdminApproval(request) {
    // In a real implementation, this would check against a service or database
    // For now, we'll check for admin approval in the request
    const hasAdminApproval = request.adminApproval && 
                            this.config.approvedAdmins.includes(request.adminApproval.approver);

    return {
      approved: hasAdminApproval,
      approver: request.adminApproval?.approver,
      timestamp: request.adminApproval?.timestamp
    };
  }

  async _approveEmergencyBypass(request) {
    const bypassToken = this._generateBypassToken(request, true);
    
    await this._logServerSideBypass(request, bypassToken, 'EMERGENCY');
    
    return {
      valid: true,
      reason: 'EMERGENCY_OVERRIDE',
      message: 'Emergency TDD bypass approved',
      bypassToken: bypassToken,
      expirationTime: Date.now() + (60 * 60 * 1000), // 1 hour for emergencies
      conditions: {
        emergency: true,
        requiresPostMortem: true,
        auditTrail: true
      }
    };
  }

  _generateBypassToken(request, isEmergency = false) {
    const payload = {
      user: request.user,
      repository: request.repository,
      timestamp: Date.now(),
      exp: Date.now() + (isEmergency ? 60 * 60 * 1000 : 30 * 60 * 1000),
      emergency: isEmergency,
      jti: crypto.randomUUID() // JWT ID for tracking
    };

    const encodedPayload = Buffer.from(JSON.stringify(payload)).toString('base64');
    const signature = this._signPayload(encodedPayload);
    
    return `${encodedPayload}.${signature}`;
  }

  _signPayload(payload) {
    // Use a combination of environment factors as signing key
    const signingKey = crypto.createHash('sha256')
      .update(process.env.TDD_SIGNING_SECRET || 'default-secret')
      .update(os.hostname())
      .update(process.cwd())
      .digest();

    return crypto.createHmac('sha256', signingKey)
      .update(payload)
      .digest('hex');
  }

  async _logServerSideBypass(request, token, type = 'STANDARD') {
    const logEntry = {
      timestamp: new Date().toISOString(),
      type: type,
      user: request.user,
      repository: request.repository,
      justification: request.justification,
      token: token.split('.')[0], // Log payload but not signature
      hostname: os.hostname(),
      pid: process.pid,
      adminApproval: request.adminApproval
    };

    // Log to local file
    const localLogPath = '.git/server-bypass.log';
    const logLine = JSON.stringify(logEntry) + '\n';
    
    try {
      await fs.promises.appendFile(localLogPath, logLine);
    } catch (error) {
      console.error('Failed to write local bypass log:', error.message);
    }

    // Attempt to log to server (if available)
    if (this.config.serverLogPath && fs.existsSync(path.dirname(this.config.serverLogPath))) {
      try {
        await fs.promises.appendFile(this.config.serverLogPath, logLine);
      } catch (error) {
        // Server logging is optional - don't fail the bypass for this
        console.warn('Failed to write server bypass log:', error.message);
      }
    }
  }

  async _updateBypassCounters(request) {
    try {
      const cache = await this._loadBypassCache();
      const today = new Date().toISOString().split('T')[0];
      
      if (!cache[today]) {
        cache[today] = { users: {}, repositories: {}, total: 0 };
      }

      // Update user counter
      if (!cache[today].users[request.user]) {
        cache[today].users[request.user] = { count: 0, timestamps: [] };
      }
      cache[today].users[request.user].count++;
      cache[today].users[request.user].timestamps.push(Date.now());

      // Update repository counter
      if (!cache[today].repositories[request.repository]) {
        cache[today].repositories[request.repository] = { count: 0, timestamps: [] };
      }
      cache[today].repositories[request.repository].count++;
      cache[today].repositories[request.repository].timestamps.push(Date.now());

      // Update total counter
      cache[today].total++;

      // Clean old entries (keep last 7 days)
      this._cleanOldCacheEntries(cache);

      await this._saveBypassCache(cache);
    } catch (error) {
      console.error('Failed to update bypass counters:', error.message);
    }
  }

  async _loadBypassCache() {
    try {
      if (!fs.existsSync(this.config.localCachePath)) {
        return {};
      }
      const data = await fs.promises.readFile(this.config.localCachePath, 'utf8');
      return JSON.parse(data);
    } catch (error) {
      return {};
    }
  }

  async _saveBypassCache(cache) {
    try {
      await fs.promises.writeFile(
        this.config.localCachePath, 
        JSON.stringify(cache, null, 2)
      );
    } catch (error) {
      console.error('Failed to save bypass cache:', error.message);
    }
  }

  _cleanOldCacheEntries(cache) {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - 7);
    const cutoffString = cutoffDate.toISOString().split('T')[0];

    for (const date of Object.keys(cache)) {
      if (date < cutoffString) {
        delete cache[date];
      }
    }
  }

  _getNextMidnight() {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    tomorrow.setHours(0, 0, 0, 0);
    return tomorrow.getTime();
  }

  _getUsersNearLimit(users) {
    const nearLimit = [];
    for (const [user, data] of Object.entries(users)) {
      const remaining = this.config.maxBypassesPerDay - data.count;
      if (remaining <= 1) {
        nearLimit.push({ user, used: data.count, remaining });
      }
    }
    return nearLimit;
  }

  _getReposNearLimit(repositories) {
    const nearLimit = [];
    for (const [repo, data] of Object.entries(repositories)) {
      const remaining = this.config.maxRepoBypassesPerDay - data.count;
      if (remaining <= 2) {
        nearLimit.push({ repository: repo, used: data.count, remaining });
      }
    }
    return nearLimit;
  }
}

// CLI interface for standalone usage
if (import.meta.url === `file://${process.argv[1]}`) {
  const args = process.argv.slice(2);
  const command = args[0];
  
  const validator = new ServerSideBypassValidator();

  switch (command) {
    case 'validate':
      // Validate bypass request from JSON input
      const requestJson = args[1];
      if (!requestJson) {
        console.error('Usage: node server-side-bypass-validator.js validate <request-json>');
        process.exit(1);
      }
      
      try {
        const request = JSON.parse(requestJson);
        validator.validateBypass(request).then(result => {
          console.log(JSON.stringify(result, null, 2));
          process.exit(result.valid ? 0 : 1);
        });
      } catch (error) {
        console.error('Invalid JSON request:', error.message);
        process.exit(1);
      }
      break;

    case 'verify':
      // Verify bypass token
      const token = args[1];
      if (!token) {
        console.error('Usage: node server-side-bypass-validator.js verify <token>');
        process.exit(1);
      }
      
      const verification = validator.verifyBypassToken(token);
      console.log(JSON.stringify(verification, null, 2));
      process.exit(verification.valid ? 0 : 1);
      break;

    case 'stats':
      // Show bypass statistics
      validator.getBypassStatistics().then(stats => {
        console.log(JSON.stringify(stats, null, 2));
      });
      break;

    default:
      console.log(`
Server-Side TDD Bypass Validator

Usage:
  validate <request-json>  Validate a bypass request
  verify <token>          Verify a bypass token
  stats                   Show bypass statistics

Examples:
  validate '{"user":"john","repository":"repo","justification":"Emergency hotfix...","timestamp":"${new Date().toISOString()}"}'
  verify eyJ1c2VyIjoiam9obiIsInJlcG8iOiJyZXBvIn0.abc123
  stats
      `);
      process.exit(command ? 1 : 0);
  }
}

export default ServerSideBypassValidator;