import Foundation

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct AttachmentPromptBuilderTestRunner {
    static func main() throws {
        let richAttachment = ChatAttachment(
            filename: "spec.docx",
            filePath: "/tmp/spec.docx",
            isImage: false,
            content: "Quarterly plan from extracted Office text"
        )

        let richTag = AttachmentPromptBuilder.fileTag(for: richAttachment)
        require(richTag != nil, "expected extracted rich-document text to be preserved")
        require(
            richTag?.contains("Quarterly plan from extracted Office text") == true,
            "expected inline tag to contain extracted rich-document text"
        )

        let plainFileURL = URL(fileURLWithPath: "/tmp/plain-inline-test.txt")
        try "print(\"hello\")".write(to: plainFileURL, atomically: true, encoding: .utf8)

        let plainAttachment = ChatAttachment(
            filename: "plain-inline-test.txt",
            filePath: plainFileURL.path,
            isImage: false,
            content: nil
        )

        let plainTag = AttachmentPromptBuilder.fileTag(for: plainAttachment)
        require(plainTag != nil, "expected UTF-8 text files to keep inline fallback")
        require(plainTag?.contains("print(\"hello\")") == true, "expected inline tag to contain file contents")

        print("attachment_prompt_builder_test: ok")
    }
}
