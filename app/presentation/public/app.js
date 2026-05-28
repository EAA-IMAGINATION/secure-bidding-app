document.addEventListener('DOMContentLoaded', function() {
  // Handle delete confirmation dialogs with proper escaping
  document.querySelectorAll('form[data-confirm-username]').forEach(function(form) {
    form.addEventListener('submit', function(e) {
      const username = form.dataset.confirmUsername;
      const message = 'Delete user ' + username + '? This action cannot be undone.';
      if (!confirm(message)) {
        e.preventDefault();
      }
    });
  });
});

// === Cryptography Helpers ===

// Base64 encoding/decoding helpers for NaCl
const CryptoUtils = {
  // Convert bytes to base64 string
  toBase64(bytes) {
    if (typeof bytes === 'string') {
      return btoa(bytes);
    }
    return btoa(String.fromCharCode(...new Uint8Array(bytes)));
  },

  // Convert base64 string to bytes
  fromBase64(str) {
    return Uint8Array.from(atob(str), c => c.charCodeAt(0));
  },

  // Generate NaCl keypair for project
  generateKeyPair() {
    if (typeof nacl === 'undefined') {
      throw new Error('NaCl library not loaded');
    }
    const kp = nacl.box.keyPair();
    return {
      publicKey: this.toBase64(kp.publicKey),
      secretKey: kp.secretKey,
      secretKeyBase64: this.toBase64(kp.secretKey)
    };
  },

  // Derive key from password using PBKDF2 (synchronous fallback via SubtleCrypto)
  async deriveKeyFromPassword(password, salt = null) {
    if (!salt) {
      salt = nacl.randomBytes(16);
    }
    
    const encoder = new TextEncoder();
    const data = encoder.encode(password);
    
    const key = await crypto.subtle.importKey('raw', data, 'PBKDF2', false, ['deriveBits']);
    
    const derivedBits = await crypto.subtle.deriveBits(
      {
        name: 'PBKDF2',
        salt: salt,
        iterations: 100000,
        hash: 'SHA-256'
      },
      key,
      256 // 32 bytes = 256 bits
    );
    
    return {
      key: new Uint8Array(derivedBits),
      salt: this.toBase64(salt)
    };
  },

  // Encrypt secret key with password-derived key using NaCl secretbox
  async encryptPrivateKeyWithPassword(secretKey, password) {
    const derived = await this.deriveKeyFromPassword(password);
    const nonce = nacl.randomBytes(nacl.secretbox.nonceLength);
    
    const encrypted = nacl.secretbox(secretKey, nonce, derived.key);
    
    return {
      ciphertext: this.toBase64(encrypted),
      nonce: this.toBase64(nonce),
      salt: derived.salt
    };
  },

  // Decrypt secret key using password
  async decryptPrivateKeyWithPassword(ciphertext, nonce, salt, password) {
    const ciphertextBytes = this.fromBase64(ciphertext);
    const nonceBytes = this.fromBase64(nonce);
    const saltBytes = this.fromBase64(salt);
    
    const derived = await this.deriveKeyFromPassword(password, saltBytes);
    
    const secretKey = nacl.secretbox.open(ciphertextBytes, nonceBytes, derived.key);
    
    if (!secretKey) {
      throw new Error('Failed to decrypt private key - invalid password');
    }
    
    return secretKey;
  },

  // Encrypt bid amount or proposal using project public key
  encryptForProject(publicKeyBase64, plaintext) {
    const projectPub = this.fromBase64(publicKeyBase64);
    const eph = nacl.box.keyPair();
    const nonce = nacl.randomBytes(nacl.box.nonceLength);
    
    const msg = new TextEncoder().encode(plaintext);
    const cipher = nacl.box(msg, nonce, projectPub, eph.secretKey);
    
    return {
      ephemeralPublicKey: this.toBase64(eph.publicKey),
      nonce: this.toBase64(nonce),
      ciphertext: this.toBase64(cipher)
    };
  },

  // Compute SHA-256 hash of a file
  async fileHash(file) {
    const buffer = await file.arrayBuffer();
    const hashBuffer = await crypto.subtle.digest('SHA-256', buffer);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
  },

  // Encrypt file content
  async encryptFile(file, publicKeyBase64) {
    const buffer = await file.arrayBuffer();
    const bytes = new Uint8Array(buffer);
    const plaintext = String.fromCharCode(...bytes);
    
    return this.encryptForProject(publicKeyBase64, plaintext);
  }
};

// Make CryptoUtils globally available
window.CryptoUtils = CryptoUtils;

// === UUID Validation Helpers ===

const UUIDValidator = {
  pattern: /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i,

  isValid(id) {
    return this.pattern.test(id.toString());
  },

  validateField(fieldId, fieldName) {
    const field = document.getElementById(fieldId);
    if (!field) return true; // Field not present on this page

    const value = field.value.trim();
    if (!value) return true; // Empty fields validated by Dry::Validation

    if (!this.isValid(value)) {
      alert(`${fieldName} must be a valid UUID (format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)`);
      field.focus();
      return false;
    }
    return true;
  },

  validateFormSubmission(form, idFields) {
    for (const { fieldId, fieldName } of idFields) {
      if (!this.validateField(fieldId, fieldName)) {
        return false;
      }
    }
    return true;
  }
};

// Make UUIDValidator globally available
window.UUIDValidator = UUIDValidator;

// === Countdown Timer & Atomic Reveal ===

const AtomicReveal = {
  // Initialize countdown timer for atomic reveal
  // Deadline is ISO 8601 string (e.g., "2026-05-28T17:30:00Z")
  initCountdown(deadlineISO, containerId = 'countdown-timer') {
    const container = document.getElementById(containerId);
    if (!container) return;

    const deadline = new Date(deadlineISO).getTime();
    
    const updateCountdown = () => {
      const now = new Date().getTime();
      const timeLeft = deadline - now;
      const revealBtn = document.getElementById('reveal-bids-btn');
      
      if (timeLeft <= 0) {
        // Deadline passed - enable reveal and check integrity
        container.innerHTML = '<span class="badge bg-success">✓ Bidding Closed</span>';
        
        // Enable reveal button if integrity snapshot is available
        if (revealBtn) {
          revealBtn.disabled = false;
          revealBtn.classList.remove('disabled');
          revealBtn.textContent = 'View Decrypted Bids';
        }
        
        // Stop updating countdown
        return true;
      }

      // Bidding still active - keep button locked
      if (revealBtn) {
        revealBtn.disabled = true;
        revealBtn.classList.add('disabled');
        revealBtn.title = 'Bids cannot be revealed until the bidding deadline passes';
      }

      const hours = Math.floor((timeLeft / (1000 * 60 * 60)) % 24);
      const minutes = Math.floor((timeLeft / (1000 * 60)) % 60);
      const seconds = Math.floor((timeLeft / 1000) % 60);
      
      const countdown = `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
      container.innerHTML = `
        <div class="d-flex align-items-center gap-2">
          <span class="badge bg-warning text-dark">Bidding Active</span>
          <span>Revealing in: <strong>${countdown}</strong></span>
          <span style="font-size: 0.85rem; color: #666;">Bids locked in cryptographic envelope</span>
        </div>
      `;
      
      return false;
    };

    updateCountdown();
    const intervalId = setInterval(() => {
      if (updateCountdown()) {
        // Deadline passed, stop updating
        clearInterval(intervalId);
      }
    }, 1000);
  },

  // Fetch and display integrity snapshot
  async fetchIntegritySnapshot(projectId) {
    try {
      // Try to fetch integrity snapshot from API
      const response = await fetch(`/api/v1/projects/${projectId}/integrity_snapshot`);
      if (!response.ok) {
        // Endpoint might not exist yet, or snapshot not available
        console.warn('Integrity snapshot not yet available');
        return null;
      }
      
      const data = await response.json();
      return data;
    } catch (err) {
      console.warn('Integrity snapshot unavailable:', err.message);
      return null;
    }
  },

  // Display integrity verification badge
  displayIntegrityBadge(integrity, containerId = 'integrity-badge') {
    const container = document.getElementById(containerId);
    if (!container) return;

    if (!integrity) {
      container.innerHTML = `
        <div class="alert alert-info alert-sm mb-0">
          <small>
            <strong>Integrity snapshot:</strong> Will be generated after bidding deadline.
            <span class="text-muted">(Currently preparing...)</span>
          </small>
        </div>
      `;
      return;
    }

    const snapshotTime = new Date(integrity.snapshot_taken_at).toLocaleString();
    const html = `
      <div class="alert alert-success alert-sm mb-0">
        <small>
          <strong>✓ Integrity Verified</strong><br>
          Hash: <code style="font-size: 0.75rem;">${integrity.canonical_hash.substring(0, 16)}...</code><br>
          Snapshot: ${snapshotTime}
        </small>
      </div>
    `;
    container.innerHTML = html;
  }
};

// Make AtomicReveal globally available
window.AtomicReveal = AtomicReveal;
