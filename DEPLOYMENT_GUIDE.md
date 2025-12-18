# Hosting Flutter Web App

Here are the two easiest and most popular ways to host your Flutter web application.

## Prerequisite: Build the Web App
Before hosting, you must build the release version of your app:
```bash
flutter build web --release
```
This will create a `build/web` directory containing your static files.

---

## Option 1: Firebase Hosting (Recommended for Google ecosystem)
Fast, secure, and integrates well if you use other Firebase services.

1. **Install Firebase CLI**:
   ```bash
   npm install -g firebase-tools
   ```
2. **Login**:
   ```bash
   firebase login
   ```
3. **Initialize**:
   Run this in your project root:
   ```bash
   firebase init hosting
   ```
   - Select "Use an existing project" or "Create a new project".
   - **Public directory**: Type `build/web`
   - **Configure as a single-page app?**: Yes
   - **Set up automatic builds and deploys with GitHub?**: Optional (No for now)

4. **Deploy**:
   ```bash
   flutter build web --release
   firebase deploy
   ```

---

## Option 2: GitHub Pages (Free & Easy)
Great if your code is already on GitHub.

1. **Enable GitHub Pages**:
   - Go to your repository **Settings** > **Pages**.
   - Source: `Deploy from a branch`.
   - Branch: `gh-pages` (we will create this).

2. **Use `flutter_gh_pages` package** (Simplest method):
   - Add dev dependency: It is not strictly necessary to add a package, you can just push the build folder, but `peanut` is a popular tool for this.
   
   **Manual Method (No extra packages):**
   ```bash
   flutter build web --release --base-href "/<REPO_NAME>/"
   ```
   *(Replace `<REPO_NAME>` with your repository name, e.g. `/Qurani/`)*

   - Go to `build/web`.
   - Initialize a git repo there:
     ```bash
     cd build/web
     git init
     git add .
     git commit -m "Deploy"
     git branch -M gh-pages
     git remote add origin <YOUR_GITHUB_REPO_URL>
     git push -u origin gh-pages --force
     ```

## Which one should I choose?
- Choose **Firebase Hosting** if you want a professional URL (e.g., `web.app`), fast global CDN, or use other Firebase features.
- Choose **GitHub Pages** if you want a completely free solution for a personal project hosted directly from your repository.
