# 🔐 Service Principal erstellen - Anleitung für Azure Portal

## Option 1: Azure Portal (GUI)

### Schritt 1: App Registration erstellen

1. Öffnen Sie das **Azure Portal** (https://portal.azure.com)
2. Navigieren Sie zu **Azure Active Directory** (oder **Microsoft Entra ID**)
3. Klicken Sie auf **App registrations** (App-Registrierungen)
4. Klicken Sie auf **+ New registration** (Neue Registrierung)
5. Geben Sie einen Namen ein: `avd-image-builder-sp`
6. Wählen Sie **Accounts in this organizational directory only**
7. Klicken Sie auf **Register**

**Notieren Sie:**
- **Application (client) ID** → Dies ist Ihre `client_id`
- **Directory (tenant) ID** → Dies ist Ihre `tenant_id`

### Schritt 2: Client Secret erstellen

1. In der App Registration, klicken Sie auf **Certificates & secrets**
2. Klicken Sie auf **+ New client secret**
3. Geben Sie eine Beschreibung ein: `Terraform Secret`
4. Wählen Sie eine Gültigkeitsdauer (z.B. 12 Monate)
5. Klicken Sie auf **Add**

**WICHTIG: Notieren Sie sofort den SECRET VALUE** (wird nur einmal angezeigt!)
- **Value** → Dies ist Ihr `client_secret`

### Schritt 3: Subscription ID finden

1. Navigieren Sie zu **Subscriptions**
2. Wählen Sie Ihre Subscription aus
3. **Notieren Sie die Subscription ID** → Dies ist Ihre `subscription_id`

### Schritt 4: Berechtigungen zuweisen

1. In Ihrer **Subscription**, klicken Sie auf **Access control (IAM)**
2. Klicken Sie auf **+ Add** → **Add role assignment**
3. Wählen Sie Role: **Contributor**
4. Klicken Sie auf **Next**
5. Klicken Sie auf **+ Select members**
6. Suchen Sie nach `avd-image-builder-sp`
7. Wählen Sie den Service Principal aus
8. Klicken Sie auf **Select**
9. Klicken Sie auf **Review + assign**

---

## Option 2: Azure CLI (falls installiert)

```bash
# Login
az login

# Subscription ID anzeigen
az account show --query id -o tsv

# Service Principal erstellen
az ad sp create-for-rbac \
  --name "avd-image-builder-sp" \
  --role "Contributor" \
  --scopes /subscriptions/{IHRE-SUBSCRIPTION-ID}
```

Die Ausgabe enthält alle benötigten Werte:
```json
{
  "appId": "...",           // → client_id
  "password": "...",        // → client_secret
  "tenant": "..."           // → tenant_id
}
```

---

## ✅ Checkliste

Nach dem Erstellen sollten Sie haben:
- [ ] `client_id` (GUID Format: 00000000-0000-0000-0000-000000000000)
- [ ] `client_secret` (String, z.B. "xyz~abc123...")
- [ ] `subscription_id` (GUID Format)
- [ ] `tenant_id` (GUID Format)

Diese Werte benötigen wir für die `terraform.tfvars` Datei.
