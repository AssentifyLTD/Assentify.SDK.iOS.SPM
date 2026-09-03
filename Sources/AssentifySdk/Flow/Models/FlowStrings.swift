import Foundation

public struct FlowStrings {

    private static var isArabic: Bool {
        BaseTheme.baseUiLanguage == UiLanguage.Arabic
    }

    // MARK: - Common Buttons

    public static var next: String { isArabic ? "التالي" : "Next" }
    public static var retry: String { isArabic ? "إعادة المحاولة" : "Retry" }
    public static var skip: String { isArabic ? "تخطي" : "Skip" }
    public static var decline: String { isArabic ? "رفض" : "Decline" }
    public static var close: String { isArabic ? "إغلاق" : "Close" }
    public static var cancel: String { isArabic ? "إلغاء" : "Cancel" }
    public static var ok: String { isArabic ? "موافق" : "OK" }
    public static var confirm: String { isArabic ? "تأكيد" : "Confirm" }
    public static var confirmed: String { isArabic ? "تم التأكيد" : "Confirmed" }
    public static var sendOtp: String { isArabic ? "إرسال رمز التحقق" : "Send OTP" }
    public static var letsStart: String { isArabic ? "لنبدأ" : "Lets Start" }
    public static var search: String { isArabic ? "بحث..." : "Search..." }
    public static var noResultsFound: String { isArabic ? "لا توجد نتائج" : "No results found" }
    public static var noDataAvailable: String { isArabic ? "لا تتوفر بيانات" : "No data available" }

    // MARK: - Block Loader

    public static func completeOnboarding(count: Int) -> String {
        if isArabic {
            let stepsWord = count == 1 ? "خطوة" : "خطوات"
            return "أكمل عملية\nالتسجيل في \(count) \(stepsWord)"
        }
        return "Complete Your\nOnboarding in \(count) " + (count == 1 ? "Step" : "Steps")
    }

    public static var onboardingSubtitle: String {
        isArabic
        ? "ستتضمن التقاط هويتك وصورة وجهك — إنها سريعة وسهلة وآمنة."
        : "It will include capturing your ID and your face — it's fast, easy, and secure."
    }

    public static var thankYou: String { isArabic ? "شكراً لك!" : "Thank you!" }

    public static func completedSteps(count: Int) -> String {
        if isArabic {
            let stepsWord = count == 1 ? "خطوة" : "خطوات"
            return "تم إكمال \(count) \(stepsWord) بنجاح"
        }
        return "Completed \(count) " + (count == 1 ? "Step" : "Steps") + " Successfully"
    }

    public static func stepLabel(number: Int, name: String) -> String {
        isArabic ? "الخطوة \(number): \(name)" : "Step \(number): \(name)"
    }

    // MARK: - Step Meta Names & Descriptions

    public static var stepTermsName: String { isArabic ? "الشروط والأحكام" : "Terms & Conditions" }
    public static var stepTermsDesc: String { isArabic ? "اقرأ واقبل الشروط والأحكام." : "Read and accept the Terms & Conditions." }

    public static var stepScanIdName: String { isArabic ? "امسح هويتك" : "Scan Your ID" }
    public static var stepScanIdDesc: String { isArabic ? "التقط صورة لهويتك الوطنية أو جواز سفرك للتحقق من هويتك." : "Take a photo of your national ID or passport to verify your identity." }

    public static var stepSelfieName: String { isArabic ? "التقط صورة سيلفي" : "Take Selfie" }
    public static var stepSelfieDesc: String { isArabic ? "استخدم الكاميرا لتأكيد هويتك بأمان من خلال مسح سيلفي سريع." : "Use your camera to securely confirm your identity with a quick selfie scan." }

    public static var stepDataEntryName: String { isArabic ? "إدخال المعلومات" : "Information Capture" }
    public static var stepDataEntryDesc: String { isArabic ? "قدّم بياناتك الشخصية الأساسية مثل الاسم والعنوان ومعلومات العمل." : "Provide basic personal details like name, address, and employment info." }

    public static var stepSigningName: String { isArabic ? "التوقيع الإلكتروني" : "eKYC Signing" }
    public static var stepSigningDesc: String { isArabic ? "قدّم توقيعاً رقمياً لإكمال عملية التسجيل." : "Provide a digital signature to complete onboarding." }

    // MARK: - ID Step

    public static var chooseCountry: String { isArabic ? "اختر بلد إقامتك" : "Choose your country of residence" }
    public static var selectDocumentType: String { isArabic ? "اختر نوع المستند" : "Select type of document" }
    public static var selectCountry: String { isArabic ? "اختر البلد" : "Select country" }
    public static var passport: String { isArabic ? "جواز السفر" : "Passport" }
    public static var supportedIds: String { isArabic ? "الهويات المدعومة" : "Supported IDs" }
    public static var viewMore: String { isArabic ? "عرض المزيد" : "View more" }
    public static var restOfTheWorld: String { isArabic ? "بقية العالم" : "Rest of the world" }

    public static func onlySupportedIds(flowName: String) -> String {
        isArabic
        ? "الهويات المعروضة فقط مدعومة ومقبولة من قبل \(flowName). تأكد من تقديم واحدة منها."
        : "Only the presented IDs are supported and accepted by \(flowName). Make sure to provide one of them."
    }

    public static var presentPassport: String { isArabic ? "قدّم جواز سفرك" : "Present Your Passport" }
    public static var presentId: String { isArabic ? "قدّم هويتك" : "Present Your ID" }
    public static var watchCapturePassport: String { isArabic ? "شاهد كم هو سهل التقاط جواز سفرك" : "Watch How Easy It Is To Capture Your Passport" }
    public static var watchCaptureId: String { isArabic ? "شاهد كم هو سهل التقاط هويتك" : "Watch How Easy It Is To Capture Your ID" }

    public static var idLightingHint: String {
        isArabic
        ? "تأكد فقط من أنك في منطقة مضاءة جيداً بدون انعكاس ضوء مباشر على الهوية أو جواز السفر المقدم."
        : "Just make sure to be in a well lit area with no direct light reflecting on the ID or Passport presented."
    }

    // MARK: - Face Step

    public static var faceMatch: String { isArabic ? "مطابقة الوجه" : "Face Match" }
    public static var watchCaptureSelfieMultiline: String { isArabic ? "شاهد كم هو سهل\nالتقاط صورة سيلفي" : "Watch How Easy It Is\nTo Take A Selfie" }
    public static var watchCaptureSelfieSingleLine: String { isArabic ? "شاهد كم هو سهل التقاط صورة سيلفي" : "Watch How Easy It Is To Take A Selfie" }

    public static var faceLivenessHint: String {
        isArabic
        ? "تتضمن صورة السيلفي التقاط حيوية للتأكد من أنك حقيقي، اتبع التعليمات على الشاشة."
        : "The selfie includes liveness capture to ensure you're real, follow the on screen instructions."
    }

    // MARK: - QR Step

    public static var captureQrCode: String { isArabic ? "التقاط رمز QR" : "Capture QR Code" }
    public static var watchCaptureQr: String { isArabic ? "شاهد كم هو سهل\nالتقاط رمز QR لهويتك" : "Watch How Easy It Is\nTo Capture Your ID Qr Code" }
    public static var qrLightingHint: String {
        isArabic
        ? "تأكد فقط من أنك في منطقة مضاءة جيداً بدون انعكاس ضوء مباشر على الهوية."
        : "Just make sure to be in a well lit area with no direct light reflecting on the ID ."
    }

    // MARK: - NFC Step

    public static var nfcPositionHint: String {
        isArabic
        ? "ضع جواز السفر في أسفل الهاتف حيث يوجد قارئ شريحة NFC وتأكد من أن جواز السفر قريب بما يكفي للكشف والقراءة."
        : "Position the passport on the bottom of the phone where the NFC chip reader is and ensure that you have the passport close enough for detection and reading."
    }
    public static var nfcReading: String { isArabic ? "جارٍ قراءة NFC..." : "Nfc reading..." }
    public static var nfcConnectionLost: String {
        isArabic
        ? "انقطع الاتصال. أبقِ الهاتف ثابتاً على جواز السفر وحاول مرة أخرى."
        : "Connection lost. Keep the phone still on the passport and try again."
    }
    public static var nfcBasedCapture: String { isArabic ? "التقاط عبر NFC" : "NFC Based Capture" }
    public static var nfcDetected: String { isArabic ? "تم اكتشاف NFC" : "NFC DETECTED" }

    // MARK: - Error / Status Screens

    public static var errorProcessId: String { isArabic ? "عذراً، تعذرت معالجة الهوية المقدمة" : "Oops unable to Process ID Provided" }
    public static var errorProcessIdHint: String {
        isArabic
        ? "تأكد من أن الهوية المقدمة واضحة وخالية من انعكاسات الضوء. حاول تقديم الهوية عمودياً إذا كانت دقة الكاميرا منخفضة لتسهيل عملية الاستخراج."
        : "Make sure presented ID is clear and does not have any light reflections on it. Try presenting the ID vertically if your camera resolution is low to ease the extraction process."
    }

    public static var processingIdWait: String { isArabic ? "جارٍ معالجة الهوية يرجى الانتظار" : "Processing ID please wait" }
    public static var uploadingIdWait: String { isArabic ? "جارٍ رفع الهوية يرجى الانتظار" : "Uploading ID please wait" }

    public static var captureBackOfId: String { isArabic ? "التقط الجهة الخلفية للهوية" : "Capture Back of ID" }
    public static var flipCardHint: String { isArabic ? "يرجى قلب البطاقة المقدمة لالتقاط الجهة الخلفية" : "Please flip the card provided to take the back of the card" }
    public static var expectedCardType: String { isArabic ? "نوع البطاقة المتوقع" : "Expected Card Type" }

    public static var wrongTemplate: String { isArabic ? "هوية غير مدعومة \n قالب خاطئ" : "Unsupported ID Provided \n Wrong Template" }

    public static func wrongTemplateHint(flowName: String) -> String {
        isArabic
        ? "تأكد من أنها واحدة من الهويات المعروضة أعلاه والمسموح بها من قبل \(flowName) للتحقق من هويتك."
        : "Make sure its one of the above IDs presented and allowed by \(flowName) to verify your identity."
    }

    public static var notRealId: String { isArabic ? "يبدو أنك لم تقدم هوية حقيقية" : "Seems like you didn't provide a real ID" }

    public static var livenessErrorTitle: String { isArabic ? "تعذر التحقق من وجه حي. يرجى المحاولة مرة أخرى." : "We couldn't verify a live face. Please try again." }
    public static var livenessErrorHint: String {
        isArabic
        ? "تعذر التحقق من وجه حي. يرجى التأكد من أنك في منطقة مضاءة جيداً وتجنب استخدام الصور أو مقاطع الفيديو"
        : "We could not verify a live face. Please ensure you are in a well-lit area, and avoid using photos or videos"
    }

    public static var letsTryAgain: String { isArabic ? "لنحاول مرة أخرى" : "Let's try again" }
    public static var faceLightHint: String {
        isArabic
        ? "يرجى التأكد من أن وجهك مضاء جيداً، انظر مباشرة إلى الكاميرا، وتجنب استخدام الصور أو مقاطع الفيديو"
        : "Please make sure your face is well lit, look directly at the camera, and avoid using photos or videos"
    }

    public static var idProcessedSuccessfully: String { isArabic ? "تمت معالجة الهوية بنجاح" : "ID Processed Successfully" }

    public static var expiredPassport: String { isArabic ? "تم اكتشاف جواز سفر منتهي الصلاحية!" : "Expired Passport Detected!" }
    public static var expiredPassportHint: String {
        isArabic
        ? "يبدو أن جواز سفرك منتهي الصلاحية. يرجى استخدام جواز سفر صالح وغير منتهي الصلاحية لإكمال عملية التحقق."
        : "Your passport appears to be expired. Please use a valid, non-expired passport to complete the verification process."
    }

    // MARK: - Submit Step

    public static var readyToSubmit: String { isArabic ? "هل أنت جاهز للإرسال؟" : "Ready to Submit?" }
    public static var swipeToConfirm: String { isArabic ? "اسحب الزر أدناه لتأكيد الإرسال." : "Swipe the button below to confirm your submission." }
    public static var submitError: String {
        isArabic
        ? "تعذر إكمال الإرسال. تحقق من اتصالك وحاول مرة أخرى."
        : "We couldn't complete your submission. Check your connection and retry."
    }
    public static var swipeToSubmit: String { isArabic ? "اسحب للإرسال" : "Swipe to Submit" }

    // MARK: - Terms

    public static var termsAndConditions: String { isArabic ? "الشروط والأحكام" : "Terms And Conditions" }

    // MARK: - Context Aware / OTP

    public static var otpVerifying: String { isArabic ? "جارٍ التحقق من رمز OTP..." : "Otp verifying ..." }
    public static var verifiedSuccessfully: String { isArabic ? "تم التحقق بنجاح" : "Verified successfully" }
    public static var sendingOtp: String { isArabic ? "جارٍ إرسال رمز التحقق..." : "Sending OTP..." }
    public static var invalidEmail: String { isArabic ? "يرجى إدخال عنوان بريد إلكتروني صالح" : "Please enter a valid email address" }
    public static var otpSendFailed: String { isArabic ? "فشل إرسال رمز التحقق. يرجى المحاولة مرة أخرى." : "Failed to send OTP. Please try again." }
    public static var invalidOtp: String { isArabic ? "رمز التحقق غير صالح. يرجى المحاولة مرة أخرى." : "Invalid OTP. Please try again." }
    public static var agreement: String { isArabic ? "اتفاقية" : "Agreement" }
    public static var agreeToTerms: String { isArabic ? "أوافق على الشروط والأحكام" : "I agree to the terms and conditions" }
    public static var filesReviewedApproved: String { isArabic ? "تمت مراجعة الملفات والموافقة عليها" : "Files Reviewed and Approved" }

    public static func otpPlaceholder(size: Int) -> String { "OTP (\(size))" }

    // MARK: - Data Entry

    public static var somethingWentWrong: String { isArabic ? "حدث خطأ ما" : "Something went wrong" }

    // MARK: - Context Aware Extra

    public static var pleaseReviewFiles: String { isArabic ? "يرجى مراجعة والموافقة على الملفات أدناه" : "Please review and approve the below files" }
    public static var thankYouApproving: String { isArabic ? "شكراً لموافقتك" : "Thank you for approving" }
    public static var emailVerificationTitle: String { isArabic ? "البريد الإلكتروني لاستلام رمز التحقق" : "Email to Receive a Verification Code" }
    public static var phoneNumberTitle: String { isArabic ? "رقم الهاتف" : "Phone Number" }

    // MARK: - Signature

    public static var signature: String { isArabic ? "التوقيع" : "Signature" }

    // MARK: - PDF Viewer

    public static var failedToLoadPdf: String { isArabic ? "فشل تحميل ملف PDF" : "Failed to load PDF" }

    // MARK: - Progress Stepper

    public static func stepOutOf(current: Int, total: Int) -> String {
        isArabic
        ? "الخطوة \(current) من \(total) خطوات"
        : "Step \(current) out of \(total) steps"
    }

    // MARK: - Field Labels (OnCompleteScreen)

    public static var labelFirstName: String { isArabic ? "الاسم الأول" : "First Name" }
    public static var labelLastName: String { isArabic ? "اسم العائلة" : "Last Name" }
    public static var labelFatherName: String { isArabic ? "اسم الأب" : "Father Name" }
    public static var labelMotherName: String { isArabic ? "اسم الأم" : "Mother Name" }
    public static var labelBirthDate: String { isArabic ? "تاريخ الميلاد" : "Birth Date" }
    public static var labelExpiryDate: String { isArabic ? "تاريخ الانتهاء" : "Expiry Date" }
    public static var labelCountry: String { isArabic ? "البلد" : "Country" }
    public static var labelNationality: String { isArabic ? "الجنسية" : "Nationality" }
    public static var labelDocumentNumber: String { isArabic ? "رقم المستند" : "Document Number" }
    public static var labelIdType: String { isArabic ? "نوع الهوية" : "ID Type" }
    public static var labelPlaceOfBirth: String { isArabic ? "مكان الولادة" : "Place of Birth" }
    public static var labelDocumentType: String { isArabic ? "نوع المستند" : "Document Type" }
    public static var labelCivilRegisterNumber: String { isArabic ? "رقم السجل المدني" : "Civil Register Number" }
    public static var labelDateOfIssuance: String { isArabic ? "تاريخ الإصدار" : "Date of Issuance" }
    public static var labelGender: String { isArabic ? "الجنس" : "Gender" }
    public static var labelMaritalStatus: String { isArabic ? "الحالة الاجتماعية" : "Marital Status" }
    public static var labelPlaceOfResidence: String { isArabic ? "مكان الإقامة" : "Place of Residence" }
    public static var labelProvince: String { isArabic ? "المحافظة" : "Province" }
    public static var labelGovernorate: String { isArabic ? "المحافظة" : "Governorate" }

    // MARK: - Dropdown / Search Dialogs

    public static var noDataAvailableShort: String { isArabic ? "لا تتوفر بيانات" : "No data available" }

    // MARK: - Email / Phone OTP Fields

    public static var enterOtp: String { isArabic ? "أدخل رمز التحقق" : "Enter OTP" }
    public static var pleaseEnterValidPhone: String { isArabic ? "يرجى إدخال رقم هاتف صالح" : "Please enter a valid phone number" }
    public static func resendOtp(_ isReady: Bool) -> String { isReady ? resendOtpReady : "" }
    public static var resendOtpReady: String { isArabic ? "إعادة إرسال رمز التحقق" : "Resend OTP" }
    public static func resendIn(_ countdown: String) -> String {
        isArabic ? "إعادة الإرسال خلال \(countdown)" : "Resend in \(countdown)"
    }

    // MARK: - Face Step Feedback

    public static var takePhoto: String { isArabic ? "التقط صورة" : "Take Photo" }
    public static var moreThanOneFace: String { isArabic ? "تم اكتشاف أكثر من وجه. يرجى إبقاء وجهك فقط في الإطار." : "We detected more than one face.Please keep just your face in view." }
    public static var moveCloser: String { isArabic ? "يرجى الاقتراب" : "Please Move Closer" }
    public static var moveFurther: String { isArabic ? "يرجى الابتعاد" : "Please Move Further" }
    public static var holdYourHand: String { isArabic ? "يرجى تثبيت يدك" : "Please Hold Your Hand" }
    public static var increaseLighting: String { isArabic ? "يرجى زيادة الإضاءة" : "Please increase the lighting" }
    public static var reduceLighting: String { isArabic ? "يرجى تقليل الإضاءة" : "Please reduce the lighting" }
    public static var tiltHeadRight: String { isArabic ? "يرجى إمالة رأسك إلى اليمين" : "Please tilt your head to the right" }
    public static var tiltHeadLeft: String { isArabic ? "يرجى إمالة رأسك إلى اليسار" : "Please tilt your head to the left" }
    public static var turnHeadRight: String { isArabic ? "يرجى تدوير رأسك إلى اليمين" : "Please turn your head to the right" }
    public static var turnHeadLeft: String { isArabic ? "يرجى تدوير رأسك إلى اليسار" : "Please turn your head to the left" }
    public static var lowerHead: String { isArabic ? "يرجى خفض رأسك" : "Please lower your head" }
    public static var raiseHead: String { isArabic ? "يرجى رفع رأسك" : "Please raise your head" }
    public static var holdSteady: String { isArabic ? "حافظ على الثبات" : "Hold Steady" }
    public static var faceWithinCircle: String { isArabic ? "يرجى وضع وجهك داخل الدائرة" : "Please face within circle" }
    public static var centerYourFace: String { isArabic ? "يرجى توسيط وجهك" : "Please center your face" }
    public static var moveFaceLeft: String { isArabic ? "يرجى تحريك وجهك لليسار" : "Please move your face left" }
    public static var moveFaceRight: String { isArabic ? "يرجى تحريك وجهك لليمين" : "Please move your face right" }
    public static var moveFaceUp: String { isArabic ? "يرجى تحريك وجهك للأعلى" : "Please move your face up" }
    public static var moveFaceDown: String { isArabic ? "يرجى تحريك وجهك للأسفل" : "Please move your face down" }
    public static var winkLeftEye: String { isArabic ? "يرجى الغمز بعينك اليسرى" : "Please wink with your left eye" }
    public static var winkRightEye: String { isArabic ? "يرجى الغمز بعينك اليمنى" : "Please wink with your right eye" }
    public static var blinkEyes: String { isArabic ? "يرجى رمش عينيك" : "Please blink your eyes" }

    public static var processingFaceWait: String { isArabic ? "جارٍ معالجة الوجه يرجى الانتظار" : "Processing Face please wait" }
    public static var uploadingFaceWait: String { isArabic ? "جارٍ رفع الوجه يرجى الانتظار" : "Uploading Face please wait" }

    // MARK: - Face Result Screen

    public static var verificationSuccessful: String { isArabic ? "تم التحقق بنجاح" : "Verification Successful" }
    public static var verificationUnsuccessful: String { isArabic ? "فشل التحقق" : "Verification UnSuccessful" }
    public static var verificationSuccessSubtitle: String { isArabic ? "لقد تمكنا من التأكد من أنه أنت!" : "We have been able to make sure its you!" }
    public static var verificationFailSubtitle: String { isArabic ? "لم يتطابق وجهك مع المستند المقدم. قدّم مستنداً آخر أو أكّد." : "Your face did not match with the provided document. Provide another document or confirm." }
    public static var matchLabel: String { isArabic ? "تطابق" : "Match" }
    public static var provideSupportingId: String { isArabic ? "قدّم هوية داعمة للمطابقة معها" : "Provide Supporting ID to match with" }
    public static var overrideAndProceed: String { isArabic ? "تجاوز والمتابعة" : "Override & Proceed" }
    public static var confirmAndProceed: String { isArabic ? "تأكيد والمتابعة" : "Confirm & Proceed" }

    // MARK: - Multiple Files Context Aware

    public static var approve: String { isArabic ? "موافقة" : "Approve" }
    public static var validateOtpFirst: String { isArabic ? "تحقق من رمز OTP أولاً" : "Validate OTP First" }
    public static var acceptTermsAndSign: String { isArabic ? "قبول الشروط والتوقيع" : "Accept Terms & Sign" }
    public static var acceptTerms: String { isArabic ? "قبول الشروط" : "Accept Terms" }

    // MARK: - Field Validation

    public static var fieldRequired: String { isArabic ? "هذا الحقل مطلوب" : "This field is required" }
    public static func minCharactersRequired(_ min: Int) -> String {
        isArabic ? "الحد الأدنى \(min) حرفاً مطلوب" : "Minimum \(min) characters required"
    }
    public static func maxCharactersAllowed(_ max: Int) -> String {
        isArabic ? "الحد الأقصى \(max) حرفاً مسموح" : "Maximum \(max) characters allowed"
    }
    public static var pleaseEnterValidValue: String { isArabic ? "يرجى إدخال قيمة صالحة" : "Please enter a valid value" }

    // MARK: - ID / Passport Card Scan Step

    public static var allIds: String { isArabic ? "كل الهويات" : "All IDs" }
    public static var moveIdCloser: String { isArabic ? "قرّب الهوية" : "Move ID Closer" }
    public static var moveIdFurther: String { isArabic ? "ابعد الهوية" : "Move ID Further" }
    public static var presentId2: String { isArabic ? "يرجى تقديم الهوية" : "Please present ID" }
    public static var centerYourId: String { isArabic ? "يرجى توسيط هويتك" : "Please center your ID" }
    public static var movePassportCloser: String { isArabic ? "قرّب جواز السفر" : "Move Passport Closer" }
    public static var movePassportFurther: String { isArabic ? "ابعد جواز السفر" : "Move Passport Further" }
    public static var pleasePresentPassport: String { isArabic ? "يرجى تقديم جواز السفر" : "Please present passport" }
    public static var centerYourCard: String { isArabic ? "يرجى توسيط البطاقة" : "Please center your card" }
    
    public static var dataRelayDialogTitle: String { isArabic ? "جارٍ المعالجة" : "Processing ..." }
    public static var dataRelayDialogMessage: String { isArabic ? "نقوم بالتحقق من بياناتك. لن يستغرق الأمر وقتاً طويلاً." : "We're validating your data. This won't take long." }
}
