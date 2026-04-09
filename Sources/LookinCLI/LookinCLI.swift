import ArgumentParser
import LookinCore

@main
struct LookinCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "viewglass",
        abstract: "Viewglass — programmable iOS runtime inspector",
        version: "0.1.0",
        subcommands: [
            AppsCommand.self,
            SessionCommand.self,
            HierarchyCommand.self,
            NodeCommand.self,
            QueryCommand.self,
            InvokeCommand.self,
            GestureCommand.self,
            TapCommand.self,
            LongPressCommand.self,
            DismissCommand.self,
            ScrollCommand.self,
            ControlCommand.self,
            ScreenshotCommand.self,
            RefreshCommand.self,
            AttrCommand.self,
            ConsoleCommand.self,
            SelectCommand.self,
            ExportCommand.self,
            DiagnoseCommand.self,
            ScanCommand.self,
        ]
    )
}
