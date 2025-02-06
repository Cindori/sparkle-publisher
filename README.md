# Sparkle Update Automation for macOS Apps 🚀

This repository contains **bash scripts** to automate the process of distributing **Sparkle** updates for macOS apps.  
With **App Center shutting down**, macOS developers need a streamlined way to **create, sign, notarize, and publish** Sparkle updates. These scripts use DropDMG, Amazon S3 and CloudFront to achieve that from a simple command.

These scripts handle:
- 📦 **Creating a DMG** from your latest Xcode build
- 🔏 **Signing & notarizing** your app with Apple
- 📝 **Generating `update.xml`** for Sparkle with changelogs
- ☁️ **Uploading the release** to Amazon S3 with CloudFront
- 🚀 **Invalidating caches** so users get the latest update instantly

For a detailed guide on setup and requirements, **read the blog post:**
👉 **[Automating Sparkle Updates](https://cindori.com/blog/developer/automating-sparkle-updates)**

---

## 📜 License

```txt
MIT License

Copyright (c) 2025 Cindori AB

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
