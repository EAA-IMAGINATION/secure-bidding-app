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
