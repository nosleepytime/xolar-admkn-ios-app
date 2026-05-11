# XOLAR Admin Native iOS App

This is a real native SwiftUI iPhone application. It is not a website and it is not a WebView.

## What it does

- Firebase Auth login
- Auto agent profile creation through your Vercel backend
- Required username setup if the agent has no username
- Native ticket list
- Full-screen native ticket conversation page
- Join Ticket
- Transfer Ticket
- Close Ticket with reason
- Send text replies
- Attach images and files without requiring text
- Edit/delete the agent's own messages
- Local missed notifications
- Tap notification to open the exact ticket
- Notification inbox inside the app
- Read notifications are deleted locally to keep storage clean

## Important notification note

This project builds an unsigned IPA. Without a signed Apple Push Notification setup, true APNs remote push notifications are not guaranteed. The app uses local notifications and foreground polling. When opened, it fetches missed notifications from the XOLAR backend.

## Setup

Open `XolarAdmin/Config.swift` and change:

```swift
static let vercelBaseURL = "https://YOUR-VERCEL-PROJECT.vercel.app"
```

Keep your Firebase API key already included or replace it if your Firebase web config changes.

## Required backend endpoint

Copy:

```txt
vercel-api-patch/api/app.js
```

into your XOLAR SUPPORT Vercel project:

```txt
api/app.js
```

Then redeploy Vercel.

## Build IPA with GitHub Actions

1. Create a GitHub repo.
2. Upload this whole project to the repo.
3. Go to `Actions`.
4. Open `Build XOLAR Admin Unsigned IPA`.
5. Click `Run workflow`.
6. Download artifact `XolarAdmin-unsigned-ipa`.
7. Inside it, you will find `XolarAdmin-unsigned.ipa`.

## Install

Use your own sideloading tool such as ESign, AltStore, Sideloadly, etc.
