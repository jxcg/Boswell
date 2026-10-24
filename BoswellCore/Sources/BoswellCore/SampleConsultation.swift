import Foundation

/// Entirely fictional. Lines 16, 23 and 24 reproduce the supplied examples;
/// the remaining conversation and all timing/confidence values are authored test data.
/// This is not a recording, model output, treatment recommendation or clinical validation.
public enum SampleConsultation {
    public static let transcript: [TranscriptLine] = {
        let lines: [(Double, Double, String)] = [
            (0, 3, "What brought you in today?"),
            (3, 7, "I've had a cough for about a week."),
            (7, 11, "It started last Tuesday and has been getting worse."),
            (11, 15, "Are you bringing anything up with the cough?"),
            (15, 19, "Yes, a little yellow phlegm since yesterday."),
            (19, 23, "Have you felt feverish?"),
            (23, 28, "My temperature was thirty-eight point two last night."),
            (28, 32, "Any trouble with your breathing?"),
            (32, 36, "Only a little breathless going upstairs."),
            (36, 40, "Any chest pain or coughing up blood?"),
            (40, 44, "No chest pain, and I haven't coughed up blood."),
            (44, 48, "Are you eating and drinking normally?"),
            (48, 52, "Drinking is fine, but I'm not very hungry."),
            (52, 56, "Any long-term conditions or regular medicines?"),
            (56, 60, "I get acid reflux, but nothing else."),
            (60, 65, "Just lansoprazole, thirty milligrams once a day, for my stomach."),
            (65, 70, "I'm allergic to codeine; it gave me a rash."),
            (70, 74, "I haven't taken antibiotics for this cough."),
            (74, 79, "Your oxygen level is ninety-seven percent."),
            (79, 84, "I can hear some crackles at the right base."),
            (84, 89, "This could be a chest infection."),
            (89, 99, "Rest and keep drinking fluids."),
            (99, 107, "I'll prescribe amoxicillin five hundred milligrams three times a day for five days."),
            (107, 115, "You can also take paracetamol, one gram up to four times a day, for the temperature."),
            (115, 120, "Come back if it gets worse or you are not improving."),
            (120, 126, "Call 999 if you become severely breathless or collapse."),
            (126, 131, "Please book a review in three days."),
            (131, 135, "Thank you, I will book that before I leave.")
        ]

        return lines.enumerated().map { index, line in
            TranscriptLine(
                id: index + 1, start: line.0, end: line.1, text: line.2,
                words: line.2.split(separator: " ").map {
                    TranscriptWord(text: String($0), confidence: 0.96)
                }
            )
        }
    }()
}
