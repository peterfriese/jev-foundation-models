# Implementation Plan: {{TASK_NAME}}

- **PRD Reference**: \`docs/prd/PRD-{{NAME}}.md\`
- **ADR Reference**: \`docs/architecture/ADR-{{NUMBER}}.md\`
- **Status**: In Progress | Completed

---

## Proposed Changes

### Apple Platform (\`apps/apple/\`)
- [ ] Create view model in local SPM package \`Packages/AppCore/\`
- [ ] Implement SwiftUI view with \`#Preview\` mock registration

### Android Platform (\`apps/android/\`)
- [ ] Implement Composable screen with state hoisting
- [ ] Add ViewModel with \`StateFlow\`

## Verification Checklist
- [ ] Apple compilation: \`flowdeck build\` passes
- [ ] Android compilation: \`./gradlew assembleDebug\` passes
- [ ] QA Simulator screenshot captured and verified
