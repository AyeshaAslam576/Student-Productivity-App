# BrainUp Privacy Policy

**Last updated:** June 13, 2026

**Effective date:** June 13, 2026

BrainUp ("we," "us," or "our") operates the BrainUp mobile application (the "App") — a student productivity tool for managing tasks, attendance, CGPA, timetables, documents, and AI-assisted study features.

This Privacy Policy explains what information we collect, how we use it, who we share it with, and what choices you have. By creating an account or using the App, you agree to this policy.

If you do not agree, please do not use the App.

---

## 1. Information We Collect

### 1.1 Account & identity information

When you register or sign in, we collect:

- **Email address**
- **Display name**
- **Profile photo** (optional — stored as compressed image data if you choose to upload one)
- **University name** (optional)
- **Authentication identifiers** from Firebase Authentication and, if you choose Google Sign-In, basic profile information provided by Google (such as name, email, and profile picture URL)

We do **not** store your Google or email password on our servers. Passwords are handled by Firebase Authentication.

### 1.2 Academic & productivity data you enter

To provide App features, we store the study-related data you create, including:

- **Tasks** — titles, descriptions, due dates, subjects, priorities, reminders, and completion status
- **Attendance** — subject names, present/absent records, and attendance summaries
- **CGPA / grades** — semester names, subject grades, credit hours, and calculated GPA/CGPA
- **Timetable** — lecture schedules (subjects, days, times, rooms, teachers)
- **Study timer sessions** — focus/break duration, subjects, and timestamps
- **Documents** — titles, tags, folders, file metadata (size, page count), OCR-extracted text, and AI-generated summaries stored in your account
- **AI tool history** — chat messages, summarizer/grammar/TTS session inputs and outputs (truncated previews may be stored)

Scanned pages, PDFs, and images are primarily stored **on your device**. We store document **metadata** and extracted text in the cloud so your library syncs across sessions.

### 1.3 Automatically collected information

We may collect:

- **Device and app information** — operating system version, app version, and general device type (collected indirectly through Firebase and Flutter platform services)
- **Usage data** — feature interactions necessary to operate sync, notifications, and authentication
- **Push notification tokens** — if you enable Firebase Cloud Messaging notifications
- **Time zone** — used to schedule local notifications at the correct local time

We do **not** sell your personal information.

---

## 2. How We Use Your Information

We use collected information to:

- Create and manage your account
- Sync your tasks, attendance, CGPA, timetable, documents metadata, and AI session history across devices
- Send **local notifications** for task reminders, lecture alerts, and study timer events (with your permission)
- Send **push notifications** via Firebase Cloud Messaging, if enabled
- Process documents and text with **AI features** (summarization, grammar checking, chatbot, document analysis, timetable parsing, and coaching messages)
- Improve reliability, security, and performance of the App
- Respond to support requests and enforce our terms

---

## 3. AI Processing & Third-Party AI Providers

BrainUp includes AI-powered features. When you use them, **text and document content you submit** (including pasted notes, uploaded PDFs, DOCX files, images processed via OCR, and chat messages) may be transmitted to **third-party AI service providers** for processing.

These providers may include:

| Provider | Purpose |
|---|---|
| **Groq** | Primary AI provider for chat, summarization, grammar, document analysis, timetable parsing, CGPA motivation, and study coaching |
| **OpenAI** | May be used for certain AI features if enabled in future updates |
| **Google (Gemini)** | May be used for certain AI features if enabled in future updates |

AI requests from the App are routed through **Firebase Cloud Functions** on Google Cloud. Your API keys are **not** embedded in the App. AI providers receive only the content needed to generate a response (e.g., text excerpts, prompts, and conversation context).

**Important:**

- Do **not** submit sensitive personal information (national ID numbers, financial data, passwords, or confidential third-party data) to AI features unless you accept that it will be processed by these providers.
- AI outputs may be inaccurate. They are for study assistance only and should not be relied on as professional, medical, or legal advice.
- AI session history may be stored in your Firebase account so you can revisit past conversations.

For each provider's own data practices, see:

- Groq: [https://groq.com/privacy-policy/](https://groq.com/privacy-policy/)
- OpenAI: [https://openai.com/policies/privacy-policy](https://openai.com/policies/privacy-policy)
- Google: [https://policies.google.com/privacy](https://policies.google.com/privacy)

---

## 4. Third-Party Services We Use

We rely on the following categories of third-party services:

| Service | Provider | Purpose |
|---|---|---|
| Authentication | Firebase Auth, Google Sign-In | Account sign-up, sign-in, password reset |
| Database & sync | Cloud Firestore (Firebase) | Store user profile and academic data |
| Cloud functions | Firebase Cloud Functions | Secure AI request proxy |
| Push messaging | Firebase Cloud Messaging | Optional push notifications |
| OCR | Google ML Kit (on-device) | Text recognition from scanned images |
| Notifications | Flutter Local Notifications | Scheduled task and lecture reminders |

Each third-party provider processes data according to its own privacy policy. Firebase and Google Cloud services are operated by **Google LLC**.

---

## 5. Data Storage & Security

- **Cloud storage:** Account and academic data are stored in **Google Firebase / Google Cloud**, in data centers operated by Google. Data is encrypted in transit (TLS/HTTPS).
- **Local storage:** Documents, scanned images, and PDFs are stored in your device's app-private storage. Only metadata and extracted text may be synced to Firestore.
- **Access controls:** Firestore security rules restrict each user to reading and writing only their own data (`users/{userId}/...`).
- **Authentication:** AI cloud functions require a signed-in Firebase user before processing requests.

No method of transmission or storage is 100% secure. We take reasonable measures to protect your data but cannot guarantee absolute security.

---

## 6. Data Retention

- We retain your data for as long as your account is active.
- AI sessions older than 30 days may be automatically deleted from your account.
- Local document files remain on your device until you delete them or uninstall the App.
- When you delete your account (see Section 8), we delete your Firestore data and Firebase Authentication record.

---

## 7. Permissions We Request

The App may request the following device permissions:

| Permission | Why we need it |
|---|---|
| **Internet** | Sync data, authenticate, and call AI services |
| **Camera** | Scan documents, scan QR codes, take profile photos |
| **Notifications** | Task reminders, lecture alerts, study timer alerts |
| **Exact alarms** | Schedule reminders at precise times (Android 12+) |

We do **not** request access to your contacts, SMS, phone calls, or precise location.

---

## 8. Your Rights & Choices

Depending on your location, you may have the right to:

- **Access** the personal data we hold about you
- **Correct** inaccurate profile information (via Edit Profile in the App)
- **Delete** your account and associated data
- **Withdraw consent** for notifications (via device settings or in-app toggles)
- **Export** your data (contact us — see Section 10)

### Account & data deletion

You can delete your account from the App:

**Profile → Danger Zone → Delete Account**

This permanently deletes:

- Your Firebase Authentication account
- Your user profile
- All tasks, attendance, CGPA, timetable, AI sessions, study sessions, and document metadata stored in Firestore

Local files on your device are removed when you uninstall the App. Deletion is **irreversible**.

If you signed in with Google, you may also revoke BrainUp's access at [https://myaccount.google.com/permissions](https://myaccount.google.com/permissions).

---

## 9. Children's Privacy

BrainUp is intended for **university and college students** and is not directed at children under 13 (or the applicable age of digital consent in your country). We do not knowingly collect personal information from children. If you believe a child has provided us data, contact us and we will delete it.

---

## 10. International Data Transfers

Your information may be processed and stored in countries other than your own, including the United States and other countries where Google/Firebase and AI providers operate data centers. By using the App, you consent to this transfer.

---

## 11. Changes to This Policy

We may update this Privacy Policy from time to time. We will revise the "Last updated" date at the top. For material changes, we may notify you through the App or by other reasonable means. Continued use after changes constitutes acceptance of the updated policy.

---

## 12. Contact Us

If you have questions, concerns, or data requests regarding this Privacy Policy, contact us at:

**Email:** [your-support-email@example.com](mailto:your-support-email@example.com)

**Developer / Company name:** [Your Company or Developer Name]

**Address:** [Your business address, city, country]

---

*This document is provided for informational purposes. It does not constitute legal advice. Consider having a qualified attorney review this policy before publishing, especially if you operate in regions with specific privacy laws (GDPR, CCPA, etc.).*
