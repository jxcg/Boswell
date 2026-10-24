import Foundation

public enum NoteSection: String, Codable, CaseIterable {
    case presentingComplaint, history, examination, assessment, plan
    case medication, safetyNetting, followUp, other
}

/// Evidence matching, not clinical verification. The worst colour wins with max().
public enum Confidence: Int, Codable, CaseIterable, Comparable {
    case green, yellow, red

    public static func < (lhs: Confidence, rhs: Confidence) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var label: String {
        switch self {
        case .green: return "Verified"
        case .yellow: return "Check"
        case .red: return "Unsupported"
        }
    }

    public var symbol: String {
        switch self {
        case .green: return "✓"
        case .yellow: return "?"
        case .red: return "!"
        }
    }
}

public struct TranscriptWord: Codable, Equatable {
    public var text: String
    public var start: Double?
    public var end: Double?
    public var confidence: Double?

    public init(text: String, start: Double? = nil, end: Double? = nil, confidence: Double? = nil) {
        self.text = text
        self.start = start
        self.end = end
        self.confidence = confidence
    }
}

public struct TranscriptLine: Codable, Equatable, Identifiable {
    public var id: Int
    /// Seconds from recording start. Nil for untimed, pasted text.
    public var start: Double?
    public var end: Double?
    public var text: String
    public var words: [TranscriptWord]

    public init(id: Int, start: Double? = nil, end: Double? = nil, text: String, words: [TranscriptWord] = []) {
        self.id = id
        self.start = start
        self.end = end
        self.text = text
        self.words = words
    }
}

public struct DraftItem: Codable, Equatable {
    public var section: NoteSection
    public var lineIDs: [Int]
    public var quote: String
    public var text: String

    public init(section: NoteSection, lineIDs: [Int], quote: String, text: String) {
        self.section = section
        self.lineIDs = lineIDs
        self.quote = quote
        self.text = text
    }
}

public struct TranscriptChunk: Codable, Equatable {
    public var index: Int
    public var contextLines: [TranscriptLine]
    public var lines: [TranscriptLine]
    public var estimatedTokens: Int

    public init(index: Int, contextLines: [TranscriptLine] = [], lines: [TranscriptLine], estimatedTokens: Int) {
        self.index = index
        self.contextLines = contextLines
        self.lines = lines
        self.estimatedTokens = estimatedTokens
    }
}

public enum DraftMethod: String, Codable {
    case guided, plainTextFallback, failed
}

public struct ChunkDraft: Codable, Equatable {
    public var chunk: TranscriptChunk
    public var items: [DraftItem]
    public var method: DraftMethod
    public var failureReason: String?
    public var seconds: Double
    public var tokensUsed: Int?

    public init(chunk: TranscriptChunk, items: [DraftItem], method: DraftMethod,
                failureReason: String? = nil, seconds: Double, tokensUsed: Int? = nil) {
        self.chunk = chunk
        self.items = items
        self.method = method
        self.failureReason = failureReason
        self.seconds = seconds
        self.tokensUsed = tokensUsed
    }
}

public enum ItemOrigin: String, Codable {
    case model, placeholder, clinician
}

public enum ReviewStatus: String, Codable {
    case pending, accepted, edited, deleted
}

public struct NoteItem: Codable, Equatable, Identifiable {
    public var id: UUID
    public var section: NoteSection
    public var draftText: String
    public var finalText: String
    public var quote: String
    public var citedLineIDs: [Int]
    public var sourceLineIDs: [Int]
    public var confidence: Confidence
    public var reasons: [String]
    public var isMedication: Bool
    public var speechConfidence: Double?
    public var origin: ItemOrigin
    public var status: ReviewStatus

    public init(id: UUID = UUID(), section: NoteSection, draftText: String, finalText: String,
                quote: String, citedLineIDs: [Int], sourceLineIDs: [Int], confidence: Confidence,
                reasons: [String] = [], isMedication: Bool = false, speechConfidence: Double? = nil,
                origin: ItemOrigin = .model, status: ReviewStatus = .pending) {
        self.id = id
        self.section = section
        self.draftText = draftText
        self.finalText = finalText
        self.quote = quote
        self.citedLineIDs = citedLineIDs
        self.sourceLineIDs = sourceLineIDs
        self.confidence = confidence
        self.reasons = reasons
        self.isMedication = isMedication
        self.speechConfidence = speechConfidence
        self.origin = origin
        self.status = status
    }
}

public enum AlertKind: String, Codable {
    case medicine, dose, allergy, urgentAdvice, safetyNetting
}

public enum AlertStatus: String, Codable {
    case open, added, dismissed
}

public struct OmissionAlert: Codable, Equatable, Identifiable {
    public var id: UUID
    public var lineID: Int
    public var kinds: [AlertKind]
    public var terms: [String]
    public var excerpt: String
    public var status: AlertStatus

    public init(id: UUID = UUID(), lineID: Int, kinds: [AlertKind], terms: [String],
                excerpt: String, status: AlertStatus = .open) {
        self.id = id
        self.lineID = lineID
        self.kinds = kinds
        self.terms = terms
        self.excerpt = excerpt
        self.status = status
    }
}

public enum SessionStatus: String, Codable {
    case recording, processing, awaitingReview, signedOff, interrupted
}

public struct SignOff: Codable, Equatable {
    public var name: String
    public var statement: String
    public var date: Date

    public init(name: String, statement: String, date: Date) {
        self.name = name
        self.statement = statement
        self.date = date
    }
}

/// Before/after text belongs in the audit trail, never in exported note wording.
public struct AuditEvent: Codable, Equatable, Identifiable {
    public var id: UUID
    public var date: Date
    public var action: String
    public var itemID: UUID?
    public var alertID: UUID?
    public var before: String?
    public var after: String?

    public init(id: UUID = UUID(), date: Date, action: String, itemID: UUID? = nil,
                alertID: UUID? = nil, before: String? = nil, after: String? = nil) {
        self.id = id
        self.date = date
        self.action = action
        self.itemID = itemID
        self.alertID = alertID
        self.before = before
        self.after = after
    }
}

public struct ProcessingReport: Codable, Equatable {
    public var chunks: [ChunkDraft]
    public var seconds: Double

    public init(chunks: [ChunkDraft], seconds: Double) {
        self.chunks = chunks
        self.seconds = seconds
    }
}

/// Storage contracts only: review/sign-off enforcement is implemented in BW-7.
public struct ConsultationSession: Codable, Equatable, Identifiable {
    public var id: UUID
    public var createdAt: Date
    public var transcript: [TranscriptLine]
    public var items: [NoteItem]
    public var alerts: [OmissionAlert]
    public var audioFileName: String?
    public var status: SessionStatus
    public var signOff: SignOff?
    public var audit: [AuditEvent]
    public var report: ProcessingReport?

    public init(id: UUID = UUID(), createdAt: Date = Date(), transcript: [TranscriptLine] = [],
                items: [NoteItem] = [], alerts: [OmissionAlert] = [], audioFileName: String? = nil,
                status: SessionStatus = .awaitingReview, signOff: SignOff? = nil,
                audit: [AuditEvent] = [], report: ProcessingReport? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.transcript = transcript
        self.items = items
        self.alerts = alerts
        self.audioFileName = audioFileName
        self.status = status
        self.signOff = signOff
        self.audit = audit
        self.report = report
    }
}
