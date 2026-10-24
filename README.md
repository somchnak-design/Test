# 🚀 PulseFlow & GitHub Pages Automated Deployment

โปรเจกต์นี้มาพร้อมกับเว็บแอปพลิเคชันต้นแบบ **PulseFlow** และระบบ **Skill: `deploy-html-pages`** ที่ช่วยสร้างและ Deploy เว็บไซต์ HTML/CSS/JS ขึ้น **GitHub Pages** อัตโนมัติ โดยผู้ใช้จะได้รับ Live URL เพื่อเข้าชมบนอินเทอร์เน็ตได้ทันที

---

## 🌟 จุดเด่นและความสามารถ (Key Features)

- **ไม่ต้องติดตั้ง Git หรือ GitHub CLI (Zero Local Git Requirement):**
  - ไม่จำเป็นต้องมีโปรแกรม `git` หรือ `gh` ติดตั้งอยู่ในเครื่อง Windows
  - ระบบทำงานผ่าน PowerShell และสื่อสารกับ **GitHub REST API v3** (`Invoke-RestMethod`) โดยตรง
- **ระบบทำงานอัตโนมัติทุกขั้นตอน (Fully Automated):**
  1. ตรวจสอบการเชื่อมต่อด้วย GitHub Personal Access Token (PAT)
  2. สร้าง Public Repository บน GitHub ให้อัตโนมัติ (หากยังไม่มี)
  3. แปลงไฟล์และอัปโหลดขึ้น branch `main` ของ GitHub
  4. สั่งเปิดระบบ GitHub Pages และชี้ไปที่ branch `main` ทันที
  5. ส่งมอบ Live URL: `https://<github-username>.github.io/<repo-name>/`
- **รองรับทั้ง Single-file และ Multi-file Projects:**
  - รองรับไฟล์เดี่ยวแบบ `index.html` (รวม CSS/JS ในตัว)
  - รองรับโฟลเดอร์โปรเจกต์ที่มีหลายไฟล์ รวมถึงโฟลเดอร์ Assets และรูปภาพ

---

## ⚙️ การเตรียมความพร้อมครั้งแรก (One-time Setup)

ก่อนเริ่ม Deploy ให้ตั้งค่า **GitHub Personal Access Token (PAT)** เพียงครั้งเดียว:

1. **สร้าง Token บน GitHub:**
   - เข้าไปที่ [GitHub Token Generator (Personal Access Token - Classic)](https://github.com/settings/tokens/new?scopes=repo)
   - ติ๊กเลือกสิทธิ์ (Scope): `repo` (Full control of private repositories)
   - กดปุ่ม **Generate token** ด้านล่างสุด แล้วคัดลอกรหัส Token ที่ขึ้นต้นด้วย `ghp_...`
2. **บันทึกลงในโปรเจกต์:**
   - คัดลอกหรือเปลี่ยนชื่อไฟล์ `.env.example` เป็น `.env`
   - ใส่รหัส Token ของคุณลงไป เช่น:
     ```env
     GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
     ```

---

## 💻 วิธีการใช้งาน (How to Use)

### วิธีที่ 1: สั่งผ่าน AI Assistant (แนะนำและง่ายที่สุด)
คุณสามารถพิมพ์สั่งในช่องแชทได้ทันที เช่น:
> *"ช่วย Deploy เว็บหน้านี้ขึ้น GitHub Pages ในชื่อ repo pulseflow-dashboard ให้หน่อย"*

AI จะตรวจสอบไฟล์ เรียกสคริปต์ Deploy และส่ง Live URL กลับมาให้คุณทันที

### วิธีที่ 2: รันคำสั่งผ่าน PowerShell ด้วยตนเอง
เปิด PowerShell ในโฟลเดอร์โปรเจกต์ แล้วรันคำสั่ง:

```powershell
powershell -ExecutionPolicy Bypass -File ".agents\skills\deploy-html-pages\scripts\deploy.ps1" -TargetPath ".\index.html" -RepoName "pulseflow-dashboard"
```

#### ตารางพารามิเตอร์ของสคริปต์ (`deploy.ps1`):
| พารามิเตอร์ | คำอธิบาย | ค่าเริ่มต้น (Default) |
| :--- | :--- | :--- |
| `-TargetPath` | เส้นทางไฟล์ `index.html` หรือโฟลเดอร์เว็บที่จะ Deploy | `index.html` หรือโฟลเดอร์ปัจจุบัน |
| `-RepoName` | ชื่อ Repository ที่ต้องการสร้างบน GitHub | ชื่อโฟลเดอร์ปัจจุบัน |
| `-RepoDescription` | คำอธิบายสั้นๆ ของ Repository | *"Web application created and deployed with Antigravity"* |
| `-Token` | รหัส GitHub PAT (ระบุเจาะจงได้) | อ่านจากตัวแปรแวดล้อม `$env:GITHUB_TOKEN` หรือไฟล์ `.env` |

---

## ⏱️ หมายเหตุเกี่ยวกับการเปิดเว็บครั้งแรก
- เมื่อระบบ Deploy สำเร็จและแจ้ง Live URL แล้ว ในการสร้าง Repository ใหม่ครั้งแรก **GitHub Pages อาจใช้เวลาประมวลผลประมาณ 30 – 90 วินาที** ก่อนที่หน้าเว็บจะแสดงผลสมบูรณ์
- สามารถเข้าไปดูสถานะการ Build ได้ที่แท็บ **Settings > Pages** ใน GitHub Repository ของคุณ

---

## 📁 โครงสร้างโปรเจกต์ (Project Structure)

```text
Test antigravity/
├── .agents/
│   └── skills/
│       └── deploy-html-pages/    # ข้อมูลและสคริปต์ของ Skill
│           ├── SKILL.md          # รายละเอียดและขั้นตอนการทำงานของ Skill
│           ├── references/       # คู่มือและเอกสารอ้างอิง
│           ├── resources/        # เทมเพลตและไฟล์ตัวอย่าง
│           └── scripts/
│               └── deploy.ps1    # สคริปต์หลักสำหรับยิง GitHub REST API
├── .env.example                  # ตัวอย่างการตั้งค่า GITHUB_TOKEN
├── index.html                    # หน้าเว็บ PulseFlow Dashboard ตัวอย่าง
└── README.md                     # เอกสารสรุปการทำงาน (ไฟล์นี้)
```
