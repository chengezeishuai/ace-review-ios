# ACE Review iOS

ACE Review is a SwiftUI client for cloud video review and device-evidence review.

## Build Contract

- Project: `ACEReview.xcodeproj`
- Scheme: `ACE Review`
- Bundle identifier: `com.ace.review`
- Deployment target: iOS 17
- Production API: `http://36.140.125.194:19080/prod-api/`

The GitHub Actions workflow at `.github/workflows/build-ios-unsigned.yml` archives the project on macOS and publishes an unsigned IPA artifact. It is a compilation gate only; an unsigned IPA cannot be installed on an iPhone.

## Signed Archive

On a macOS machine with Xcode and the correct Apple developer team/certificate installed, set `DEVELOPMENT_TEAM` in the Xcode target and run:

```bash
xcodebuild \
  -project ACEReview.xcodeproj \
  -scheme "ACE Review" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath build/ACEReview.xcarchive \
  archive
```

Export the resulting archive with an App Store Connect, Ad Hoc, or Development export options plist appropriate to the certificate and provisioning profile. Do not add certificates, provisioning profiles, Apple ID passwords, or API tokens to this repository.



