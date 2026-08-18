# End-to-End CI/CD Pipeline (Jenkins + Docker + SonarQube + Maven + Nexus + AWS EC2)

This repository contains a **complete, working CI/CD pipeline project** you can build, run, and put on your GitHub profile to match your resume line:

> Built an automated CI/CD pipeline using Jenkins for build, test, code quality analysis, and deployment. Integrated GitHub, Maven, SonarQube, and Nexus to automate software delivery.

It includes:
- A small Spring Boot Java app (something real for the pipeline to build/test/deploy)
- A `Jenkinsfile` defining the full pipeline (checkout → build → test → SonarQube → Nexus → Docker → deploy → email)
- A `Dockerfile` to containerize the app
- Shell scripts to install Jenkins, Docker, Maven, SonarQube, and Nexus on AWS EC2
- This README, which walks through **every single step**, including AWS console clicks, Jenkins plugin names, and credential setup

---

## Architecture

```
GitHub (source code)
      |
      v
Jenkins (EC2 instance #1) --- pulls code, orchestrates everything
      |
      |---> Maven: compile + run unit tests
      |---> SonarQube (EC2 instance #2): static code analysis + quality gate
      |---> Nexus (EC2 instance #3): stores the built .jar artifact
      |---> Docker: builds an image, pushes to Docker Hub
      |---> Deploy: SSH into EC2 instance #4 and run the new container
      |
      v
Email notification sent to you (success/failure)
```

You can run everything on ONE EC2 instance for learning purposes (see "Cost-saving single-instance setup" at the bottom), or split it across 4 instances to mirror a real environment — both are covered below.

---

## Prerequisites

- An AWS account (Free Tier is enough for a single-instance setup)
- A GitHub account
- A Docker Hub account (free) — for pushing images
- Basic comfort with SSH and the Linux terminal

---

## Part 1 — Push this project to GitHub

1. Create a new **empty** repository on GitHub, e.g. `cicd-pipeline-project` (do NOT initialize it with a README — you already have one here).
2. On your local machine, from inside this project folder, run:
   ```bash
   git init
   git add .
   git commit -m "Initial commit: CI/CD pipeline project"
   git branch -M main
   git remote add origin https://github.com/YOUR_USERNAME/cicd-pipeline-project.git
   git push -u origin main
   ```
3. Confirm all files (Jenkinsfile, Dockerfile, pom.xml, src/, scripts/, README.md) appear in GitHub.

---

## Part 2 — Launch your AWS EC2 instance(s)

Repeat these steps for each server you need (Jenkins, SonarQube, Nexus, Deploy target — or just once if doing the single-instance setup).

1. Log into the **AWS Console** → **EC2** → **Launch Instance**.
2. **Name**: `jenkins-server` (or `sonarqube-server`, `nexus-server`, `deploy-server`).
3. **AMI**: Ubuntu Server 22.04 LTS.
4. **Instance type**:
   - Jenkins: `t2.medium` (t2.micro is too small once builds run)
   - SonarQube: `t3.medium` (needs 2GB+ RAM)
   - Nexus: `t3.medium`
   - Deploy target: `t2.micro` is fine
5. **Key pair**: create a new key pair (e.g. `cicd-key.pem`), download it, keep it safe.
6. **Network settings** → **Edit** → add inbound rules:
   | Type | Port | Source |
   |---|---|---|
   | SSH | 22 | My IP |
   | Custom TCP | 8080 | 0.0.0.0/0 (Jenkins UI / app) |
   | Custom TCP | 9000 | 0.0.0.0/0 (SonarQube UI) |
   | Custom TCP | 8081 | 0.0.0.0/0 (Nexus UI) |
7. Click **Launch Instance**.
8. Once running, copy its **Public IPv4 address** — you'll need it constantly below.
9. Connect via SSH:
   ```bash
   chmod 400 cicd-key.pem
   ssh -i cicd-key.pem ubuntu@<EC2_PUBLIC_IP>
   ```

---

## Part 3 — Install Jenkins

On your **Jenkins EC2 instance**:

1. Copy `scripts/install-jenkins.sh` onto the server (via `scp` or just paste its contents into a new file with `nano install-jenkins.sh`).
2. Run it:
   ```bash
   chmod +x install-jenkins.sh
   sudo ./install-jenkins.sh
   ```
3. The script prints the **initial admin password** at the end — copy it.
4. In your browser, go to `http://<JENKINS_EC2_IP>:8080`.
5. Paste the initial admin password.
6. Click **Install suggested plugins** and wait.
7. Create your first admin user (username/password you'll actually remember).
8. Click **Save and Finish** → **Start using Jenkins**.

### Install Docker + Maven on the Jenkins server
Still on the Jenkins EC2 instance:
```bash
chmod +x install-docker-maven.sh
sudo ./install-docker-maven.sh
sudo reboot
```
Reconnect via SSH after the reboot (group membership for Docker needs a fresh session).

### Install additional Jenkins plugins
In Jenkins UI: **Manage Jenkins → Plugins → Available plugins**, search for and install each of these:
- `Maven Integration`
- `Pipeline`
- `Git`
- `SonarQube Scanner`
- `Docker Pipeline`
- `SSH Agent`
- `Email Extension Plugin`
- `Nexus Artifact Uploader` (optional — we use plain `mvn deploy` instead, but it's handy)

Restart Jenkins after installing (checkbox at the bottom of the plugin install page).

### Configure global tools
**Manage Jenkins → Tools**:
- Under **JDK installations**: Add JDK, name it `JDK11`, uncheck "Install automatically" and set `JAVA_HOME` to `/usr/lib/jvm/java-11-openjdk-amd64` (or check "Install automatically" if you prefer).
- Under **Maven installations**: Add Maven, name it `Maven3`, check "Install automatically" (or point it at the Maven you installed).

---

## Part 4 — Install SonarQube

On your **SonarQube EC2 instance**:
```bash
chmod +x install-sonarqube.sh
sudo ./install-sonarqube.sh
```
Wait 1–2 minutes, then open `http://<SONARQUBE_EC2_IP>:9000`.
- Log in with `admin` / `admin` → you'll be prompted to set a new password immediately.

### Generate a SonarQube token for Jenkins
1. In SonarQube: click your profile icon (top right) → **My Account → Security**.
2. Under **Generate Tokens**, name it `jenkins-token`, click **Generate**, and **copy the token immediately** (it's shown only once).

### Connect SonarQube to Jenkins
1. In Jenkins: **Manage Jenkins → Credentials → System → Global credentials → Add Credentials**.
   - Kind: `Secret text`
   - Secret: paste the SonarQube token
   - ID: `sonar-token`
2. **Manage Jenkins → System**, scroll to **SonarQube servers**:
   - Check "Environment variables"
   - Name: `MySonarQubeServer` (must match the `SONARQUBE_ENV` value in the Jenkinsfile)
   - Server URL: `http://<SONARQUBE_EC2_IP>:9000`
   - Server authentication token: select `sonar-token`
3. Save.

### Set up the Quality Gate webhook (so Jenkins knows pass/fail instantly)
In SonarQube: **Administration → Configuration → Webhooks → Create**.
- Name: `jenkins`
- URL: `http://<JENKINS_EC2_IP>:8080/sonarqube-webhook/`

---

## Part 5 — Install Nexus

On your **Nexus EC2 instance**:
```bash
chmod +x install-nexus.sh
sudo ./install-nexus.sh
```
Wait 2–3 minutes (Nexus is slow to boot the first time), then open `http://<NEXUS_EC2_IP>:8081`.

1. Get the initial admin password:
   ```bash
   sudo docker exec nexus cat /nexus-data/admin.password
   ```
2. Click **Sign in** (top right) → log in as `admin` with that password → set a new password → enable anonymous access or not, your choice.
3. Confirm the default repositories `maven-releases` and `maven-snapshots` exist under **Repository → Repositories**.

### Add Nexus credentials in Jenkins
**Manage Jenkins → Credentials → Add Credentials**:
- Kind: `Username with password`
- Username/password: your Nexus admin login
- ID: `nexus-creds`

### Add Nexus credentials to Maven's settings.xml (on the Jenkins server)
On the Jenkins EC2 instance, edit `/var/lib/jenkins/.m2/settings.xml` (create the `.m2` folder if it doesn't exist):
```xml
<settings>
  <servers>
    <server>
      <id>nexus-releases</id>
      <username>admin</username>
      <password>YOUR_NEXUS_PASSWORD</password>
    </server>
    <server>
      <id>nexus-snapshots</id>
      <username>admin</username>
      <password>YOUR_NEXUS_PASSWORD</password>
    </server>
  </servers>
</settings>
```
(The `id` values must match the `<id>` tags in this project's `pom.xml` under `<distributionManagement>`.)

### Update pom.xml
In `pom.xml`, replace `NEXUS_SERVER_IP` with your actual Nexus EC2 public IP in both repository URLs.

---

## Part 6 — Docker Hub setup

1. Create a free account at https://hub.docker.com if you don't have one.
2. Create a repository, e.g. `demo-cicd-app`.
3. In Jenkins: **Manage Jenkins → Credentials → Add Credentials**:
   - Kind: `Username with password`
   - Username/password: your Docker Hub login
   - ID: `dockerhub-creds`
4. In the `Jenkinsfile`, replace `yourdockerhubusername` with your actual Docker Hub username.

---

## Part 7 — Set up the deployment target server

This is the EC2 instance your app actually runs on after each successful pipeline.

1. Launch it (see Part 2), install Docker only:
   ```bash
   sudo apt update -y && sudo apt install -y docker.io
   sudo systemctl enable docker && sudo systemctl start docker
   sudo usermod -aG docker ubuntu
   ```
2. Open port `8080` in its security group so you can view the running app.
3. In Jenkins: **Manage Jenkins → Credentials → Add Credentials**:
   - Kind: `SSH Username with private key`
   - ID: `ec2-ssh-key`
   - Username: `ubuntu`
   - Private key: paste the contents of your `cicd-key.pem`
4. In the `Jenkinsfile`, replace `DEPLOY_SERVER_IP` with this instance's public IP.

---

## Part 8 — Connect GitHub to Jenkins

### Add GitHub credentials
1. On GitHub: **Settings → Developer settings → Personal access tokens → Tokens (classic) → Generate new token**, scope: `repo`. Copy it.
2. In Jenkins: **Manage Jenkins → Credentials → Add Credentials**:
   - Kind: `Username with password`
   - Username: your GitHub username
   - Password: the personal access token
   - ID: `github-creds`

### Set up the webhook (auto-trigger builds on push)
1. In your GitHub repo: **Settings → Webhooks → Add webhook**.
2. Payload URL: `http://<JENKINS_EC2_IP>:8080/github-webhook/`
3. Content type: `application/json`
4. Trigger: "Just the push event"
5. Save.

---

## Part 9 — Set up email notifications

1. **Manage Jenkins → System → Extended E-mail Notification**:
   - SMTP server: e.g. `smtp.gmail.com`
   - SMTP port: `465` (SSL) or `587` (TLS)
   - Credentials: add a Jenkins credential with your email + an **app password** (not your regular Gmail password — generate one under Google Account → Security → App Passwords)
   - Check "Use SSL" or "Use TLS" as appropriate
2. Under **Manage Jenkins → System → E-mail Notification**, set the default Jenkins admin email too.
3. In `Jenkinsfile`, replace `you@example.com` with your real email address.

---

## Part 10 — Create the Jenkins Pipeline job

1. Jenkins dashboard → **New Item**.
2. Name: `cicd-pipeline-project`, type: **Pipeline** → OK.
3. Under **Build Triggers**, check **GitHub hook trigger for GITScm polling**.
4. Under **Pipeline**:
   - Definition: `Pipeline script from SCM`
   - SCM: `Git`
   - Repository URL: `https://github.com/YOUR_USERNAME/cicd-pipeline-project.git`
   - Credentials: select `github-creds`
   - Branch: `*/main`
   - Script Path: `Jenkinsfile`
5. Save.

---

## Part 11 — Run it

1. Click **Build Now** (or just `git push` to your repo — the webhook triggers it automatically).
2. Watch the stages run in the **Stage View**.
3. If a stage fails, click into it and read the **Console Output** — it tells you exactly which command failed.
4. On success:
   - Check SonarQube dashboard for the new analysis
   - Check Nexus `maven-releases` repo for the uploaded jar
   - Check Docker Hub for the pushed image
   - Visit `http://<DEPLOY_SERVER_IP>:8080/` — you should see: `CI/CD Pipeline Demo App is running!`
   - Check your inbox for the success email

---

## Cost-saving single-instance setup

If you don't want to pay for 4 EC2 instances, you can run Jenkins, SonarQube, and Nexus all as Docker containers on **one** larger instance (`t3.large`, 8GB RAM recommended):

```bash
# On one Ubuntu EC2 instance, after installing Docker:
sudo docker run -d --name jenkins -p 8080:8080 -p 50000:50000 -v jenkins_home:/var/jenkins_home jenkins/jenkins:lts
sudo docker run -d --name sonarqube -p 9000:9000 sonarqube:lts-community
sudo docker run -d --name nexus -p 8081:8081 -v nexus-data:/nexus-data sonatype/nexus3
```
Then use `localhost` (or `host.docker.internal` from inside the Jenkins container) for the SonarQube/Nexus URLs instead of separate IPs. Note: Jenkins running inside a container needs the Docker socket mounted (`-v /var/run/docker.sock:/var/run/docker.sock`) to build/push images itself.

---

## Troubleshooting

| Problem | Likely fix |
|---|---|
| `docker: permission denied` in Jenkins logs | Jenkins user isn't in the `docker` group — re-run `sudo usermod -aG docker jenkins` and restart Jenkins |
| SonarQube container keeps restarting | Increase `vm.max_map_count` (see install script) and make sure the instance has 2GB+ RAM |
| `mvn deploy` fails with 401 | Check `settings.xml` credentials match Nexus login, and repo `id`s match `pom.xml` |
| Webhook doesn't trigger builds | Confirm Jenkins URL is publicly reachable on port 8080 and the webhook payload URL ends in `/github-webhook/` |
| Email not sending | Use an app password, not your real password; check SMTP port/SSL settings |

---

## What to put on your resume / LinkedIn (once this is live)

- Link to this GitHub repo
- A short GIF or screenshot of the Jenkins pipeline stage view (green, all stages passing)
- Mention: "Designed and deployed a fully automated CI/CD pipeline (GitHub → Jenkins → Maven → SonarQube → Nexus → Docker → AWS EC2) with automated testing, code quality gates, and email notifications."

---

## Project structure

```
cicd-pipeline-project/
├── README.md
├── Jenkinsfile
├── Dockerfile
├── pom.xml
├── src/
│   ├── main/java/com/example/demo/DemoApplication.java
│   ├── main/java/com/example/demo/controller/HelloController.java
│   └── test/java/com/example/demo/DemoApplicationTests.java
└── scripts/
    ├── install-jenkins.sh
    ├── install-docker-maven.sh
    ├── install-sonarqube.sh
    └── install-nexus.sh
```
