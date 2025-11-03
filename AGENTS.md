# AGENTS.md

## Build Commands
- Build: `xcodebuild -project AnnoyingToggl.xcodeproj -scheme AnnoyingToggl build`
- Clean build: `xcodebuild -project AnnoyingToggl.xcodeproj -scheme AnnoyingToggl clean build`
- Run: Open in Xcode and use Cmd+R, or `xcodebuild -project AnnoyingToggl.xcodeproj -scheme AnnoyingToggl build && open build/Release/AnnoyingToggl.app`

## Test Commands
- Run all tests: `xcodebuild -project AnnoyingToggl.xcodeproj -scheme AnnoyingToggl test`
- Run single test: `xcodebuild -project AnnoyingToggl.xcodeproj -scheme AnnoyingToggl -only-testing:TestTarget/TestClass/testMethod test`

## Code Style Guidelines
- **Imports**: Group imports alphabetically, one per line at file top
- **Formatting**: 4-space indentation, consistent spacing around operators
- **Types**: Use structs for value types, classes for reference types. Prefer immutable properties.
- **Naming**: CamelCase for types/structs/classes, camelCase for variables/functions/properties
- **Error Handling**: Use do-catch with try await for async operations, print errors for debugging
- **Concurrency**: Use async/await pattern, avoid completion handlers
- **Architecture**: SwiftUI views with @EnvironmentObject for state management</content>
<parameter name="filePath">/Users/robert/Documents/personal/annoying-toggl/xcode/AnnoyingToggl/AGENTS.md