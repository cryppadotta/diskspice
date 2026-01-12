# 052: Set Up App Signing and Notarization

## Dependencies
- 001 (Xcode project setup)
- 009 (build scanner binary)

## Task
Configure code signing and notarization for distribution outside App Store.

## Spec Reference
See SPEC.md > Distribution: "Notarized for Gatekeeper"

## Implementation Details

1. Configure signing identity in Xcode
2. Sign the Rust binary separately
3. Set up notarization workflow
4. Create notarization script

```bash
# Sign and notarize
xcrun notarytool submit DiskSpice.app.zip --apple-id $APPLE_ID --password $APP_PASSWORD --team-id $TEAM_ID --wait
xcrun stapler staple DiskSpice.app
```

## Files to Create/Modify
- Xcode project - Signing configuration
- `scripts/notarize.sh` - Notarization script
- `DiskSpice/Scanner/build-scanner.sh` - Add signing

## Acceptance Criteria
- [ ] App signed with Developer ID
- [ ] Rust binary signed
- [ ] App notarized successfully
- [ ] Stapled notarization ticket
- [ ] Gatekeeper allows launch
- [ ] No security warnings on download

## Completion Promise
`<promise>TICKET_052_COMPLETE</promise>`
