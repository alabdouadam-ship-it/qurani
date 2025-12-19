# Hosting Flutter Web App

## Prerequisite: Build the Web App
Before hosting, you must build the release version of your app:
```bash
flutter build web --release
```
This will create a `build/web` directory containing your static files. This folder contains everything you need (`index.html`, `main.dart.js`, `assets/`, etc.).

---

## **Option 3: Self-Hosted Linux Server (Nginx)**
Since you have your own Linux server, using **Nginx** is the most efficient way to serve the static files.

### 1. Build & Transfer Files
1.  Run the build command locally:
    ```bash
    flutter build web --release
    ```
2.  Transfer the contents of `build/web` to your server (e.g., using `scp` or FileZilla).
    ```bash
    # Example using SCP
    scp -r build/web/* user@your-server-ip:/var/www/qurani/
    ```
    *(Ensure the destination folder `/var/www/qurani/` exists on the server)*

### 2. Configure Nginx
1.  SSH into your server.
2.  Create a new Nginx configuration file (e.g., `/etc/nginx/sites-available/qurani`).
    ```nginx
    server {
        listen 80;
        server_name your-domain.com; # Or your server IP

        root /var/www/qurani;
        index index.html index.htm;

        location / {
            try_files $uri $uri/ /index.html;
        }

        # Optional: Cache static assets for better performance
        location ~* \.(?:ico|css|js|gif|jpe?g|png)$ {
            expires 30d;
            add_header Pragma public;
            add_header Cache-Control "public";
        }
    }
    ```
    *Note: The `try_files $uri $uri/ /index.html;` line is crucial for Flutter's routing to work correctly when users refresh the page.*

3.  Enable the site and restart Nginx:
    ```bash
    sudo ln -s /etc/nginx/sites-available/qurani /etc/nginx/sites-enabled/
    sudo nginx -t
    sudo systemctl restart nginx
    ```

---

## Option 1: Firebase Hosting (Google Ecosystem)
1.  Install tools: `npm install -g firebase-tools`
2.  Login: `firebase login`
3.  Init: `firebase init hosting` (Choose `build/web` as public directory, "Yes" to single-page app).
4.  Deploy: `firebase deploy`

## Option 2: GitHub Pages (Free)
1.  Build with repo name as base path:
    ```bash
    flutter build web --release --base-href "/<REPO_NAME>/"
    ```
2.  Push contents of `build/web` to a `gh-pages` branch on your repo.
