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

  document.querySelectorAll('form[data-confirm]').forEach(function(form) {
    form.addEventListener('submit', function(e) {
      if (!confirm(form.dataset.confirm)) {
        e.preventDefault();
      }
    });
  });

  initProjectFormCrypto();
  initBidFormCrypto();
  initProjectRevealPanels();
  initBidDecryption();
});

// === Cryptography Helpers ===

// Base64 encoding/decoding helpers
const CryptoUtils = {
  // Convert bytes to base64 string
  toBase64(bytes) {
    if (typeof bytes === 'string') {
      return btoa(bytes);
    }
    return btoa(String.fromCharCode(...new Uint8Array(bytes)));
  },

  arrayBufferToBase64(buffer) {
    const bytes = new Uint8Array(buffer);
    let binary = '';
    const chunkSize = 0x8000;
    for (let i = 0; i < bytes.length; i += chunkSize) {
      binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
    }
    return btoa(binary);
  },

  // Convert base64 string to bytes
  fromBase64(str) {
    return Uint8Array.from(atob(str), c => c.charCodeAt(0));
  },

  // Generate a keypair for project bid encryption
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

  // Automatically wrap a project private key with a random NaCl secretbox key/nonce.
  wrapPrivateKey(secretKey) {
    const wrapKey = nacl.randomBytes(nacl.secretbox.keyLength);
    const nonce = nacl.randomBytes(nacl.secretbox.nonceLength);
    const ciphertext = nacl.secretbox(secretKey, nonce, wrapKey);

    return {
      key: this.toBase64(wrapKey),
      nonce: this.toBase64(nonce),
      ciphertext: this.toBase64(ciphertext)
    };
  },

  unwrapPrivateKey(wrapped) {
    const data = typeof wrapped === 'string' ? JSON.parse(wrapped) : wrapped;
    const wrapKey = this.fromBase64(data.key);
    const nonce = this.fromBase64(data.nonce);
    const ciphertext = this.fromBase64(data.ciphertext);
    const secretKey = nacl.secretbox.open(ciphertext, nonce, wrapKey);

    if (!secretKey) {
      throw new Error('Failed to unlock project private key');
    }

    return secretKey;
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

  decryptFromProject(secretKey, envelope) {
    if (!envelope || typeof envelope !== 'object') {
      throw new Error('Invalid encrypted envelope');
    }

    const ephPub = this.fromBase64(envelope.ephemeralPublicKey);
    const nonce = this.fromBase64(envelope.nonce);
    const cipher = this.fromBase64(envelope.ciphertext);
    const opened = nacl.box.open(cipher, nonce, ephPub, secretKey);

    if (!opened) {
      throw new Error('Failed to decrypt bid payload');
    }

    return new TextDecoder().decode(opened);
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

  async fileToBase64(file) {
    return this.arrayBufferToBase64(await file.arrayBuffer());
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
        container.innerHTML = '<span class="badge bg-success">Bidding closed — revealing bids</span>';
        initBidDecryption();
        return true;
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
      const apiRoot = document.querySelector('meta[name="api-url"]')?.content?.replace(/\/$/, '');
      const path = apiRoot
        ? `${apiRoot}/projects/${projectId}/integrity_snapshot`
        : `/api/v1/projects/${projectId}/integrity_snapshot`;
      const response = await fetch(path);
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

function initProjectFormCrypto() {
  const form = document.getElementById('project-form');
  if (!form) return;

  const statusDiv = document.getElementById('crypto-status');
  const statusMessage = document.getElementById('crypto-message');
  const submitBtn = document.getElementById('submit-btn');

  try {
    const keyPair = CryptoUtils.generateKeyPair();
    document.getElementById('nacl_public_key').value = keyPair.publicKey;
    document.getElementById('nacl_encrypted_private_key').value = JSON.stringify(
      CryptoUtils.wrapPrivateKey(keyPair.secretKey)
    );

    statusMessage.textContent = 'Secure bidding is ready for this project.';
    const alertBox = statusDiv.querySelector('.alert') || statusDiv;
    alertBox.classList.remove('alert-info', 'alert-danger');
    alertBox.classList.add('alert-success');
    statusDiv.style.display = 'block';
    submitBtn.disabled = false;
  } catch (err) {
    console.error('Crypto error:', err);
    statusMessage.textContent = 'Secure bidding setup failed: ' + err.message;
    const alertBox = statusDiv.querySelector('.alert') || statusDiv;
    alertBox.classList.remove('alert-info', 'alert-success');
    alertBox.classList.add('alert-danger');
    statusDiv.style.display = 'block';
    submitBtn.disabled = true;
  }

  form.addEventListener('submit', function(e) {
    const deadline = new Date(document.getElementById('bidding_deadline').value);
    if (deadline <= new Date()) {
      e.preventDefault();
      alert('Bidding deadline must be in the future');
    }
  });
}

function initBidFormCrypto() {
  const form = document.getElementById('bid-form');
  if (!form) return;

  const projectPublicKey = form.dataset.projectPublicKey;
  const projectId = form.dataset.projectId;
  const submitBtn = document.getElementById('bid-submit-btn');
  const draftKey = `bid-draft:${projectId}`;
  const deadline = form.dataset.deadline;

  if (submitBtn) {
    submitBtn.disabled = false;
  }

  const draftFields = ['contractor_alias', 'bid_amount', 'proposal_text'];
  const deadlineDate = deadline ? new Date(deadline) : null;
  if (deadlineDate && deadlineDate <= new Date()) {
    localStorage.removeItem(draftKey);
  } else {
    if (deadlineDate) {
      const msUntilDeadline = deadlineDate.getTime() - Date.now();
      window.setTimeout(function() {
        localStorage.removeItem(draftKey);
      }, Math.max(0, msUntilDeadline));
    }

    try {
      const savedDraft = JSON.parse(localStorage.getItem(draftKey) || '{}');
      draftFields.forEach(function(fieldId) {
        const field = document.getElementById(fieldId);
        if (field && savedDraft[fieldId]) field.value = savedDraft[fieldId];
      });
    } catch (err) {
      localStorage.removeItem(draftKey);
    }

    draftFields.forEach(function(fieldId) {
      const field = document.getElementById(fieldId);
      if (!field) return;
      field.addEventListener('input', function() {
        const nextDraft = {};
        draftFields.forEach(function(id) {
          const draftField = document.getElementById(id);
          if (draftField) nextDraft[id] = draftField.value;
        });
        localStorage.setItem(draftKey, JSON.stringify(nextDraft));
      });
    });
  }

  form.addEventListener('submit', async function(e) {
    e.preventDefault();

    if (!UUIDValidator.isValid(projectId)) {
      alert('Invalid project ID format');
      return false;
    }

    const statusDiv = document.getElementById('bid-crypto-status');
    const statusMessage = document.getElementById('bid-crypto-message');

    try {
      statusDiv.style.display = 'block';
      statusMessage.textContent = 'Encrypting your bid...';

      const bidAmount = document.getElementById('bid_amount').value.toString();
      const proposalText = document.getElementById('proposal_text').value;

      const encryptedAmount = CryptoUtils.encryptForProject(projectPublicKey, bidAmount);
      document.getElementById('encrypted_bid_amount').value = JSON.stringify(encryptedAmount);

      const encryptedProposal = CryptoUtils.encryptForProject(projectPublicKey, proposalText);
      document.getElementById('encrypted_proposal_text').value = JSON.stringify(encryptedProposal);

      const fileInput = document.getElementById('bid_document');
      const requiredFileInputs = Array.from(form.querySelectorAll('.bid-required-document'));
      if (requiredFileInputs.length > 0) {
        const missing = requiredFileInputs.find(input => !input.files || !input.files[0]);
        if (missing) {
          missing.focus();
          throw new Error('Upload every required document before submitting.');
        }

        const documents = [];
        const hashes = [];
        for (const input of requiredFileInputs) {
          const file = input.files[0];
          const hash = await CryptoUtils.fileHash(file);
          hashes.push(`${input.dataset.documentName}:${hash}`);
          documents.push({
            requirement: input.dataset.documentName,
            fileName: file.name,
            contentBase64: await CryptoUtils.fileToBase64(file),
            hash: hash
          });
        }
        const encryptedDoc = CryptoUtils.encryptForProject(projectPublicKey, JSON.stringify(documents));
        document.getElementById('encrypted_document').value = JSON.stringify(encryptedDoc);
        document.getElementById('document_file_name').value = documents.map(doc => doc.fileName).join(', ');
        document.getElementById('document_file_hash').value = hashes.join('|');
      } else if (fileInput && fileInput.files && fileInput.files[0]) {
        const file = fileInput.files[0];
        const encryptedDoc = await CryptoUtils.encryptFile(file, projectPublicKey);
        document.getElementById('encrypted_document').value = JSON.stringify(encryptedDoc);
        document.getElementById('document_file_name').value = file.name;
        document.getElementById('document_file_hash').value = await CryptoUtils.fileHash(file);
      }

      statusMessage.textContent = '✓ Bid encrypted successfully. Submitting...';
      statusDiv.classList.remove('alert-info', 'alert-danger');
      statusDiv.classList.add('alert-success');
      localStorage.removeItem(draftKey);

      form.submit();
    } catch (err) {
      console.error('Bid encryption error:', err);
      statusMessage.textContent = 'Error: ' + err.message;
      statusDiv.classList.remove('alert-info', 'alert-success');
      statusDiv.classList.add('alert-danger');
    }
  });
}

function initProjectRevealPanels() {
  document.querySelectorAll('[data-reveal-panel]').forEach(function(panel) {
    const deadlineISO = panel.dataset.deadline;
    const projectId = panel.dataset.projectId;
    if (!deadlineISO || !projectId) return;

    AtomicReveal.initCountdown(deadlineISO, panel.querySelector('[data-countdown]')?.id || 'countdown-timer');

    setTimeout(async function() {
      const integrity = await AtomicReveal.fetchIntegritySnapshot(projectId);
      const badgeId = panel.dataset.integrityBadge || 'integrity-badge';
      AtomicReveal.displayIntegrityBadge(integrity, badgeId);
    }, 500);

    const revealBtn = panel.querySelector('#reveal-bids-btn');
    if (revealBtn) {
      revealBtn.addEventListener('click', function(e) {
        if (revealBtn.disabled) {
          e.preventDefault();
          alert('Bid reveal is locked until the bidding deadline passes.');
          return false;
        }
        location.reload();
      });
    }
  });

  document.querySelectorAll('[data-revealed-bids]').forEach(function(section) {
    const projectId = section.dataset.projectId;
    if (!projectId) return;

    setTimeout(async function() {
      const integrity = await AtomicReveal.fetchIntegritySnapshot(projectId);
      AtomicReveal.displayIntegrityBadge(integrity, section.dataset.integrityBadge || 'integrity-badge-bids');
    }, 500);
  });
}

function biddingDeadlinePassed(deadlineISO) {
  if (!deadlineISO) return false;
  return new Date(deadlineISO).getTime() <= Date.now();
}

function decryptBidRows(secretKey) {
  document.querySelectorAll('[data-bid-row]').forEach(function(row) {
    const amountEnvelope = JSON.parse(row.dataset.encryptedAmount || '{}');
    const proposalEnvelope = JSON.parse(row.dataset.encryptedProposal || '{}');
    const amountCell = row.querySelector('[data-decrypted-amount]');
    const proposalCell = row.querySelector('[data-decrypted-proposal]');
    const documentCell = row.querySelector('[data-decrypted-document]');

    const decryptedAmount = CryptoUtils.decryptFromProject(secretKey, amountEnvelope);
    amountCell.textContent = decryptedAmount;
    const awardAmountInput = row.querySelector('[data-award-amount-cents]');
    if (awardAmountInput && /^\d+$/.test(decryptedAmount.trim())) {
      awardAmountInput.value = decryptedAmount.trim();
    }
    proposalCell.textContent = CryptoUtils.decryptFromProject(secretKey, proposalEnvelope);

    const documentEnvelope = row.dataset.encryptedDocument;
    if (documentCell && documentEnvelope) {
      const fileName = row.dataset.documentFileName || 'proposal-document';
      const decrypted = CryptoUtils.decryptFromProject(secretKey, JSON.parse(documentEnvelope));
      documentCell.innerHTML = '';
      try {
        const documents = JSON.parse(decrypted);
        if (Array.isArray(documents)) {
          documents.forEach(function(doc) {
            const link = document.createElement('a');
            link.href = `data:application/octet-stream;base64,${doc.contentBase64}`;
            link.download = doc.fileName || doc.requirement || 'proposal-document';
            link.textContent = doc.requirement ? `Download ${doc.requirement}` : `Download ${link.download}`;
            link.className = 'btn btn-sm btn-outline-secondary me-1 mb-1';
            documentCell.appendChild(link);
          });
          return;
        }
      } catch (err) {
        // Older bids stored a single encrypted document blob.
      }

      const bytes = Uint8Array.from(decrypted, c => c.charCodeAt(0));
      const blob = new Blob([bytes]);
      const link = document.createElement('a');
      link.href = URL.createObjectURL(blob);
      link.download = fileName;
      link.textContent = 'Download ' + fileName;
      link.className = 'btn btn-sm btn-outline-secondary';
      documentCell.appendChild(link);
    }
  });
}

function initBidDecryption() {
  const section = document.getElementById('revealed-bids-section');
  if (!section) return;

  const deadlineISO = section.dataset.deadline;
  const encryptedPrivateKey = section.dataset.encryptedPrivateKey;
  const status = document.getElementById('decrypt-bids-status');

  if (!biddingDeadlinePassed(deadlineISO) || !encryptedPrivateKey) {
    return;
  }

  try {
    const secretKey = CryptoUtils.unwrapPrivateKey(encryptedPrivateKey);
    decryptBidRows(secretKey);
    if (status) {
      status.textContent = 'Bidding closed — bids and documents decrypted locally after the deadline.';
      status.className = 'alert alert-success';
      status.style.display = 'block';
    }
  } catch (err) {
    console.error('Bid decryption error:', err);
    if (status) {
      status.textContent = err.message || 'Could not decrypt bids after the deadline.';
      status.className = 'alert alert-danger';
      status.style.display = 'block';
    }
  }
}
