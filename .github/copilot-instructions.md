# Copilot Instructions: Secure Bidding App (Frontend)

## Critical: No AI Co-Author Trailers

**Hard Rule:** Never include any AI co-author trailer in commit messages. If a
commit message contains `Co-authored-by: Copilot` or any AI co-author trailer,
remove it immediately before committing.

The developer is the sole author. Commit messages should reflect this clearly.

## Weekly Scope Gate (Hard Rule)

1. Never work ahead of the weekly professor requirements.
2. Keep future-facing skills and UI patterns available as references, but only
   apply them when that week's spec explicitly requires them.
3. At the start of each task, map requirements to the smallest relevant feature
   set.
4. If a requested implementation is outside current week scope, defer it and
   document it as future roadmap work only.

## Backend: Secure Bidding API Reference

The frontend consumes a Ruby/Roda REST API at `http://localhost:9292/api/v1`.

### Core API Endpoints

**Authentication (Future):**
- Authentication and authorization not yet implemented in API
- All current endpoints are open (future weeks will add auth)

**Accounts:**
- `GET /api/v1/accounts` - List all accounts
- `GET /api/v1/accounts/:id` - Fetch account
- `POST /api/v1/accounts` - Create account
- `PATCH /api/v1/accounts/:id` - Update account
- `GET /api/v1/accounts/search` - Search by email/phone
- `GET /api/v1/accounts/:id/system_roles` - List user roles
- `POST /api/v1/accounts/:id/system_roles` - Assign system role

**Projects:**
- `GET /api/v1/projects` - List projects
- `GET /api/v1/projects/:id` - Fetch project details
- `POST /api/v1/projects` - Create project
- `GET /api/v1/projects/:id/memberships` - List project team
- `POST /api/v1/projects/:id/memberships` - Add team member
- `POST /api/v1/projects/:id/bids` - Create bid for project

**Bid Submissions:**
- `GET /api/v1/bid_submissions` - List all bid submissions
- `GET /api/v1/bid_submissions/:id` - Fetch bid submission
- `POST /api/v1/bid_submissions` - Create bid submission
- `GET /api/v1/projects/:id/bid_submissions` - List bids for project

**Payments:**
- `POST /api/v1/payments` - Create payment record
- `GET /api/v1/payments/:id` - Fetch payment details
- `PATCH /api/v1/payments/:id` - Update payment (e.g., mark as paid)

### Data Model Summary

- **Account**: User with username, email (encrypted), phone (encrypted), roles
- **Project**: Bidding project with title, budget_cents
- **BidSubmission**: Encrypted bid for a project (contractor_alias, plaintext_bid)
- **ProjectMembership**: Account assigned to project with role (e.g., bidder, owner)
- **Payment**: Payment record for bid submission access/viewing

### Security Notes for Frontend

- Backend enforces encrypted storage for PII (email, phone)
- Bid data is encrypted at rest
- No authentication layer exists yet (add in future weeks per spec)
- Frontend should never store passwords in local storage
- When auth is added, use JWT token in Authorization header

## Project Skills and Rules

### 1. Feature Branch Workflow

**Rule:** Never work directly from `main`/`master`.

Before any edits, check the current branch: `git branch --show-current`

If on `main` or `master`, create/switch to a feature branch immediately.

**When to use:** At the start of every new feature.

**Workflow:**
1. Create a branch named for the feature (example: `1-account-signup`)
2. Implement and test on that branch only
3. Create a pull request for review before merging

### 2. Weekly Scope Gating

**Rule:** Only implement features specified in the current week's assignment.

**When to use:** At the beginning of every weekly assignment task.

- Map requirements to the smallest relevant feature set
- Defer out-of-scope features with clear future-roadmap documentation
- Do not implement auth, payments, or advanced features early
- Follow the professor's stated weekly increments

### 3. Component/Module Architecture

**Rule:** Maintain strict separation of concerns.

- **Components** (`src/components/`): UI elements (buttons, forms, cards)
- **Pages** (`src/pages/`): Full page views (dashboard, project list)
- **Services** (`src/services/`): API calls and business logic
- **State** (`src/state/` or store): Centralized state management (if using)
- **Utils** (`src/utils/`): Helpers (formatting, validation, parsing)
- **Tests** (`src/**/*.test.js`): Colocated with their implementation

Each feature should have a clear boundary. Services handle API integration;
components handle rendering; pages orchestrate everything.

### 4. API Integration Patterns

**Rule:** Isolate all API calls in service modules.

**When to use:** Before adding any feature that fetches or posts data.

**Pattern:**
```js
// src/services/accountService.js
export async function getAccounts() {
  const response = await fetch('http://localhost:9292/api/v1/accounts');
  if (!response.ok) throw new Error('Failed to fetch accounts');
  return response.json();
}

export async function createAccount(username, email, password, phone, system_role) {
  const response = await fetch('http://localhost:9292/api/v1/accounts', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username, email, password, phone, system_role })
  });
  if (!response.ok) throw new Error('Failed to create account');
  return response.json();
}
```

- Always check response status before parsing JSON
- Throw errors with descriptive messages
- Return parsed JSON on success
- Keep error handling in the service layer

### 5. Frontend Testing

**Rule:** Write tests for components, services, and page logic.

**When to use:** Before or alongside feature implementation (Red-Green-Refactor).

**Patterns:**
- Use Jest (or Vitest) for unit tests
- Use React Testing Library (or equivalent) for component tests
- Write HAPPY and SAD path tests for all forms and API calls
- Mock API calls in tests; do not make real HTTP requests
- Clear state/cache between tests

**Example (Jest + React Testing Library):**
```js
describe('AccountForm', () => {
  it('submits form with valid data', async () => {
    const { getByLabelText, getByRole } = render(<AccountForm />);
    fireEvent.change(getByLabelText(/username/i), { target: { value: 'demo' } });
    fireEvent.click(getByRole('button', { name: /submit/i }));
    // assert success state
  });

  it('shows error on failed submission', async () => {
    jest.spyOn(accountService, 'createAccount').mockRejectedValue(new Error('Network error'));
    // render, interact, assert error message
  });
});
```

### 6. Build and Development Commands

**Rule:** Keep build and test commands simple and documented.

**Core commands:**
```bash
npm install              # Install dependencies
npm run dev             # Start dev server (likely localhost:3000 or 5173)
npm run build           # Build for production
npm run test            # Run all tests
npm run test:watch     # Run tests in watch mode
npm run lint            # Run linter (ESLint)
npm run format          # Format code (Prettier)
```

Before committing:
```bash
npm run test
npm run lint
```

### 7. State Management (If Applicable)

**Rule:** Choose state management scope based on weekly requirements.

**Week 1-2 (Simple):** Use React hooks (`useState`, `useContext`) for local state

**Week 3+ (Complex):** Introduce Redux, Zustand, or similar if spec requires

**Pattern:** Keep state in services/context; pass down through props or context

### 8. Security-First Frontend

**Rule:** Never expose or transmit sensitive data unnecessarily.

- Never store passwords in local storage
- Use environment variables for API URLs (e.g., `REACT_APP_API_URL`)
- Never log passwords or auth tokens
- Use HTTPS in production (enforce with CSP headers)
- Validate user input before sending to API
- Escape output to prevent XSS
- Do not hardcode secrets or API keys in source code

### 9. Markdown Linting

**Rule:** After editing any `.md` file, always run markdown linting before finishing.

```bash
npx markdownlint-cli2 "**/*.md" "#node_modules" 2>&1
```

### 10. Commit Authorship

**Rule:** Commit only after tests pass, keep message short/meaningful, NEVER add
any AI co-author trailer, and ask whether to push.

**Workflow:**
1. Run `npm run test` and `npm run lint` to ensure all checks pass
2. Stage files: `git add .`
3. Create commit with short, meaningful message: `git commit -m "Add account login form"`
4. Ask the developer: "Ready to push to remote?"

**Hard Stop:** If draft message contains `Co-authored-by: Copilot` or any AI
co-author trailer, remove it immediately before presenting or running commit.

### 11. Delivery Checkpoint

**Rule:** At end of weekly implementation, run full test suite, prepare staged
commit, and ask developer to execute final push.

**Checklist:**
- [ ] All tests pass: `npm run test`
- [ ] Linter passes: `npm run lint`
- [ ] README updated if needed
- [ ] No unresolved TODO comments
- [ ] Commit message is clear and short
- [ ] No AI co-author trailers in commit
- [ ] Developer executes commit manually
- [ ] Developer decides whether to push

## Architecture

This is a React (or framework-agnostic) frontend for the Secure Bidding API.

### Directory Structure

```
src/
├── components/          # Reusable UI components
├── pages/              # Full page views
├── services/           # API calls and business logic
├── state/              # State management (context, Redux, etc.)
├── utils/              # Helper functions
├── styles/             # Global and component styles
├── App.js              # Main app component
└── index.js            # Entry point

public/                 # Static assets
tests/                  # Test files (or colocate with components)
.env.example            # Environment variable template
.github/
├── copilot-instructions.md  # This file
└── skills/              # Future skill modules (TBD)
```

### Environment Variables

Create `.env` in the project root (copy from `.env.example`):

```
REACT_APP_API_URL=http://localhost:9292/api/v1
```

Do NOT commit `.env` with real secrets.

### Dependencies (Typical)

- `react` - UI framework
- `react-dom` - React DOM rendering
- `react-router-dom` - Client-side routing
- `axios` or `fetch` - HTTP client (choose one)
- `jest` - Testing framework
- `@testing-library/react` - React component testing
- `eslint` - Linter
- `prettier` - Code formatter

Development setup will specify exact versions per week.

## API Startup and Testing

Before running the frontend, ensure the backend is running:

```bash
# Terminal 1: Backend (from secure-bidding-api/)
bundle install
cp config/secrets-example.yml config/secrets.yml
mkdir -p app/db/store
bundle exec rake db:migrate
bundle exec rake db:seed
bundle exec rackup -p 9292

# Terminal 2: Frontend (from secure-bidding-app/)
npm install
npm run dev
```

To verify API is accessible:
```bash
curl http://localhost:9292/
# Expected: {"message":"Secure Bidding API v1.0","status":"ok"}
```

## Key Conventions

### Naming

- Use kebab-case for file names: `account-form.js`, `project-list.js`
- Use PascalCase for component names: `AccountForm`, `ProjectList`
- Use camelCase for variables and functions: `getAccounts()`, `currentProject`

### Code Organization

- One component per file
- Import statements at the top, internal dependencies first, external last
- Keep components small and focused (single responsibility)
- Use descriptive variable names

### API Response Handling

- Assume successful responses return JSON with 200/201 status
- Error responses return JSON with 400/404 status and `{ error: "message" }`
- Always validate before using API data

### Component Patterns

```jsx
// Simple functional component with hooks
export function AccountCard({ account }) {
  return (
    <div className="card">
      <h3>{account.username}</h3>
      <p>ID: {account.id}</p>
    </div>
  );
}

// Component with API call
export function AccountList() {
  const [accounts, setAccounts] = useState([]);
  const [error, setError] = useState(null);

  useEffect(() => {
    accountService.getAccounts()
      .then(setAccounts)
      .catch(err => setError(err.message));
  }, []);

  if (error) return <div>Error: {error}</div>;
  return (
    <div>
      {accounts.map(account => <AccountCard key={account.id} account={account} />)}
    </div>
  );
}
```

### Testing Patterns

- Test component rendering
- Test user interactions (clicks, form submissions)
- Test API integration with mocked calls
- Test error states
- Use descriptive test names

## Current Focus

- Weekly incremental feature delivery per professor's assignment
- Tight API integration with secure-bidding-api
- Comprehensive testing with HAPPY/SAD paths
- Security-first patterns (no secrets in code, no password logging)
- Clean separation of concerns (components, services, state)

## Future Capability Skills (Reference Only)

These will be created and used only when weekly specs require them:

- `.github/skills/authentication-flow.md` (JWT, session management)
- `.github/skills/encryption-ui.md` (Display/input for encrypted bids)
- `.github/skills/role-based-ui.md` (Conditional rendering based on roles)
- `.github/skills/payment-flow.md` (Payment integration and verification)
- `.github/skills/form-validation.md` (Client-side validation rules)

## References

- API Repo: <https://github.com/EAA-IMAGINATION/secure-bidding-api>
- Frontend Repo: <https://github.com/EAA-IMAGINATION/secure-bidding-app>
- API Documentation: See `PROJECT_CONTEXT.md` in secure-bidding-api
- Weekly Assignments: Provided by professor

---

**Last Updated:** 2026-05-04  
**Status:** Initial setup for frontend development  
**Next Step:** Confirm framework choice (React/Vue/Vanilla) and create Week 1 project scaffold
