# 053: Create DMG for Distribution

## Dependencies
- 052 (app signing notarization)

## Task
Create a polished DMG installer for distribution.

## Spec Reference
See SPEC.md > Distribution: "Direct download only (website/GitHub releases)"

## Implementation Details

Use create-dmg or similar tool to create DMG with:
- Custom background image
- App icon positioned nicely
- Symbolic link to Applications folder
- Proper window size and icon arrangement

```bash
create-dmg \
  --volname "DiskSpice" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "DiskSpice.app" 150 190 \
  --app-drop-link 450 185 \
  --background "dmg-background.png" \
  "DiskSpice.dmg" \
  "DiskSpice.app"
```

## Files to Create/Modify
- `scripts/create-dmg.sh` - DMG creation script
- `Resources/dmg-background.png` - Background image
- `Resources/dmg-icon.icns` - Volume icon

## Acceptance Criteria
- [ ] DMG created successfully
- [ ] Custom background image
- [ ] App icon + Applications shortcut layout
- [ ] Proper volume name "DiskSpice"
- [ ] DMG opens with correct window size
- [ ] File size reasonable (compressed)
- [ ] Ready for GitHub releases

## Completion Promise
`<promise>TICKET_053_COMPLETE</promise>`
