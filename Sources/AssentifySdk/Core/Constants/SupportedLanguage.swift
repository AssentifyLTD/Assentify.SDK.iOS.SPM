
import Foundation

var  FullNameKey = "FullName"

func getSelectedWords(input: String, numberOfWords: Int) -> String {
    guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
    let words = input.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ")
    return words.prefix(numberOfWords).joined(separator: " ")
}

func getRemainingWords(input: String, numberOfWords: Int) -> String {
    guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
    let words = input.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ")
    return words.count <= numberOfWords ? "" : words.dropFirst(numberOfWords).joined(separator: " ")
}


public struct Language {
      public static let Text = "Text"
      public static let English = "en"
      public static let Arabic = "ar"
      public static let Azerbaijani = "az"
      public static let Belarusian = "be"
      public static let Georgian = "ka"
      public static let Korean = "ko"
      public static let Latvian = "lv"
      public static let Lithuanian = "lt"
      public static let Punjabi = "pa"
      public static let Russian = "ru"
      public static let Sanskrit = "sa"
      public static let Sindhi = "sd"
      public static let Thai = "th"
      public static let Turkish = "tr"
      public static let Ukrainian = "uk"
      public static let Urdu = "ur"
      public static let Uyghur = "ug"
      public static let NON = "NON"
}


public struct LanguageTransformationEnum {
    public static let Transliteration = 1
    public static let Translation = 2
}

