import Foundation
import XCTest
import BoswellCore

final class ModelsTests: XCTestCase {
    func testWorstConfidenceAndAccessibleKey() {
        XCTAssertEqual(max(.yellow, Confidence.red), .red)
        XCTAssertEqual(max(.green, Confidence.yellow), .yellow)
        XCTAssertEqual(max(.green, Confidence.red), .red)
        XCTAssertEqual(Confidence.allCases.map(\.label), ["Verified", "Check", "Unsupported"])
        XCTAssertEqual(Confidence.allCases.map(\.symbol), ["✓", "?", "!"])
    }

    func testSectionOrderMatchesClinicalNoteOrder() {
        XCTAssertEqual(NoteSection.allCases, [
            .presentingComplaint, .history, .examination, .assessment, .plan,
            .medication, .safetyNetting, .followUp, .other
        ])
    }

    func testSessionRoundTripPreservesEvidenceReviewAndReport() throws {
        let transcript = SampleConsultation.transcript
        let item = NoteItem(
            section: .medication, draftText: "Paracetamol 500 mg four times a day.",
            finalText: "Paracetamol 1 g up to four times a day.",
            quote: "paracetamol, one gram up to four times a day", citedLineIDs: [2],
            sourceLineIDs: [24], confidence: .red, reasons: ["500 is not in the transcript."],
            isMedication: true, speechConfidence: 0.96, status: .edited
        )
        let alert = OmissionAlert(
            lineID: 16, kinds: [.medicine, .dose], terms: ["lansoprazole", "30 mg"],
            excerpt: transcript[15].text, status: .dismissed
        )
        let chunk = TranscriptChunk(index: 1, contextLines: Array(transcript[20...21]),
                                    lines: Array(transcript[22...]), estimatedTokens: 180)
        let fallback = ChunkDraft(
            chunk: chunk,
            items: [DraftItem(section: .medication, lineIDs: [24], quote: item.quote, text: item.draftText)],
            method: .plainTextFallback, seconds: 2.5, tokensUsed: 217
        )
        let failed = ChunkDraft(chunk: chunk, items: [], method: .failed,
                                failureReason: "Model unavailable", seconds: 0.5)
        let date = Date(timeIntervalSince1970: 1_700_000_123)
        let session = ConsultationSession(
            createdAt: date, transcript: transcript, items: [item], alerts: [alert],
            audioFileName: "fictional.m4a", status: .signedOff,
            signOff: SignOff(name: "Fictional Clinician", statement: "Test approval", date: date),
            audit: [AuditEvent(date: date, action: "edit", itemID: item.id,
                               before: item.draftText, after: item.finalText)],
            report: ProcessingReport(chunks: [fallback, failed], seconds: 3)
        )

        let data = try JSONEncoder().encode(session)
        let restored = try JSONDecoder().decode(ConsultationSession.self, from: data)
        XCTAssertEqual(restored, session)
        // In particular, resolved evidence must never replace what the model actually cited.
        XCTAssertEqual(restored.items[0].citedLineIDs, [2])
        XCTAssertEqual(restored.items[0].sourceLineIDs, [24])
        XCTAssertEqual(restored.items[0].confidence, .red)
        XCTAssertEqual(restored.items[0].finalText, "Paracetamol 1 g up to four times a day.")
    }

    func testUntimedPastedTranscriptAndAbsentMetadataRoundTrip() throws {
        let line = TranscriptLine(id: 1, text: "A fictional pasted conversation.",
                                  words: [TranscriptWord(text: "fictional")])
        let session = ConsultationSession(transcript: [line])
        let restored = try JSONDecoder().decode(
            ConsultationSession.self, from: JSONEncoder().encode(session)
        )
        XCTAssertEqual(restored, session)
        XCTAssertNil(restored.transcript[0].start)
        XCTAssertNil(restored.transcript[0].end)
        XCTAssertNil(restored.transcript[0].words[0].confidence)
        XCTAssertNil(restored.audioFileName)
        XCTAssertNil(restored.signOff)
        XCTAssertNil(restored.report)
    }

    func testFictionalSampleRetainsSuppliedEvidenceLines() {
        let lines = SampleConsultation.transcript
        XCTAssertEqual(lines.map(\.id), Array(1...28))
        XCTAssertEqual(lines[15].text, "Just lansoprazole, thirty milligrams once a day, for my stomach.")
        XCTAssertEqual(lines[22].start, 99)
        XCTAssertEqual(lines[22].text,
                       "I'll prescribe amoxicillin five hundred milligrams three times a day for five days.")
        XCTAssertEqual(lines[23].text,
                       "You can also take paracetamol, one gram up to four times a day, for the temperature.")
    }
}
