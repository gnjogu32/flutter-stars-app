# DNS Record Conflict - starpage.org

## Error Message
```
Record name [@] conflicts with another record.
```

---

## What This Means

You're trying to add a DNS record to the root domain (`@` or `starpage.org`), but **a record with the same name already exists** in your DNS configuration.

**Common causes:**
- Multiple A records for the same domain
- Both A record and CNAME record for `@`
- Leftover records from previous attempts
- Auto-created records from domain registrar

---

## How to Fix It

### Step 1: Access Your Domain Registrar

Go to your domain registrar and log in:

| Registrar | URL |
|-----------|-----|
| **Google Domains** | https://domains.google.com |
| **Namecheap** | https://www.namecheap.com/dashboard |
| **GoDaddy** | https://www.godaddy.com/domains |
| **CloudFlare** | https://dash.cloudflare.com |
| **AWS Route 53** | https://console.aws.amazon.com/route53 |

---

### Step 2: View Current DNS Records

#### Google Domains
1. Click your domain: `starpage.org`
2. Left sidebar → **DNS**
3. Scroll down to **Custom records**
4. Look for records with Name = `@` or blank (root)

#### Namecheap
1. Click **Domain List**
2. Click **Manage** for `starpage.org`
3. Click **Advanced DNS** tab
4. Look for entries with Host = `@`

#### GoDaddy
1. Select domain `starpage.org`
2. Click **Manage DNS**
3. Look for entries with Name = `@`

#### CloudFlare
1. Select domain zone
2. Go to **DNS** section
3. Look for entries with Name = `starpage.org` or `@`

#### AWS Route 53
1. Click **Hosted zones**
2. Select `starpage.org`
3. Look for records with Name = `starpage.org`

---

### Step 3: Identify Conflicting Records

**Find all records pointing to the root domain (@) with these types:**

| Type | Purpose | Should Keep? |
|------|---------|--------------|
| **A** | IPv4 address (Firebase IP) | ✅ Keep ONE |
| **AAAA** | IPv6 address (Firebase IP) | ✅ Keep ONE |
| **CNAME** | Domain alias | ❌ **CONFLICTS with A/AAAA** |
| **MX** | Email records | ✅ Keep if you use email |
| **TXT** | Text records (SPF, DKIM) | ✅ Keep all |
| **ALIAS** | Domain alias (Google Domains) | ❌ **CONFLICTS with A/AAAA** |

**⚠️ CONFLICT ISSUE:**
- **Cannot have both A record AND CNAME for the same name**
- **Cannot have both A record AND ALIAS for the same name**
- Firebase requires **A and AAAA records** (not CNAME)

---

### Step 4: Delete Conflicting Records

#### If you see multiple A records for `@`:
1. Keep only **ONE** A record pointing to Firebase
2. Delete any duplicates
3. Delete any old A records pointing elsewhere

#### If you see both A record AND CNAME for `@`:
1. **Delete the CNAME** (Firebase uses A records)
2. Keep the A record pointing to Firebase IP

#### If you see ALIAS record for `@`:
1. **Delete the ALIAS**
2. Use A record instead (see Step 5)

---

### Step 5: Add Correct Records

After removing conflicting records, add:

#### A Record (IPv4)
```
Name: @ (or leave blank)
Type: A
Value: [Firebase provided IPv4 - typically 199.36.158.100 or similar]
TTL: 3600
```

#### AAAA Record (IPv6)
```
Name: @ (or leave blank)
Type: AAAA
Value: [Firebase provided IPv6]
TTL: 3600
```

#### Get Firebase IP Addresses

In Firebase Console:
1. Go to **Hosting** → **Custom domains**
2. Click your domain: `starpage.org`
3. Click **Manage custom domain**
4. Look for **DNS records required** section
5. Copy the A and AAAA record values

---

## Common Scenarios & Solutions

### Scenario 1: Multiple A Records
```
@ A 1.2.3.4      (Old registrar default)
@ A 5.6.7.8      (Firebase IP)
```
**Solution:** Delete the first one, keep Firebase IP

### Scenario 2: A Record + CNAME Conflict
```
@ A 199.36.158.100
@ CNAME flutter-stars-web.web.app
```
**Solution:** Delete the CNAME, keep the A record

### Scenario 3: ALIAS Record (Google Domains)
```
@ ALIAS flutter-stars-web.web.app
```
**Solution:** Delete ALIAS, add A record instead

### Scenario 4: Leftover Records from Testing
```
@ A 93.184.216.34      (Old IP from previous attempt)
@ A 199.36.158.100     (Current Firebase IP)
@ MX mail.starpage.org  (Email record - OK to keep)
```
**Solution:** Delete old A records, keep Firebase A record and any needed MX/TXT records

---

## Step-by-Step Example: Google Domains

### 1. Access DNS
1. Go to https://domains.google.com
2. Click `starpage.org`
3. Left menu → **DNS**

### 2. View Records
Scroll to **Custom records** section

### 3. Look for Root Domain Records
Find entries where **Name** is blank or shows `@` or `starpage.org`

### 4. Delete Conflicting Records
1. Find non-Firebase A records
2. Click **✕** (trash icon)
3. Confirm deletion

### 5. Keep or Add Firebase Records
Ensure you have:
```
Name: (blank/@)
Type: A
Data: [Firebase IPv4]
TTL: 3600
```

And:
```
Name: (blank/@)
Type: AAAA
Data: [Firebase IPv6]
TTL: 3600
```

### 6. Save
Changes save automatically

---

## Step-by-Step Example: Namecheap

### 1. Access DNS
1. Go to https://www.namecheap.com/dashboard
2. Click **Domain List**
3. Click **Manage** for `starpage.org`
4. Click **Advanced DNS** tab

### 2. View Records
Look at the list of DNS records

### 3. Find Root Domain Records
Find entries where **Host** = `@`

### 4. Delete Conflicting Records
1. Find non-Firebase A records
2. Click **Delete**
3. Confirm

### 5. Add Firebase Records
Click **+ Add Record**

Record 1:
```
Type: A Record
Host: @
Value: [Firebase IPv4]
TTL: 3600
Save
```

Record 2:
```
Type: AAAA Record
Host: @
Value: [Firebase IPv6]
TTL: 3600
Save
```

---

## Verification

After fixing DNS records:

### 1. Wait for Propagation
DNS changes take 5-15 minutes globally

### 2. Check DNS Status
```bash
# Windows
nslookup starpage.org

# Mac/Linux
dig starpage.org +short
```

Expected output: Firebase IPv4 address (e.g., 199.36.158.100)

### 3. Verify in Firebase Console
1. Go to **Hosting** → **Custom domains**
2. Click `starpage.org`
3. Check status:
   - ✅ Domain verified
   - ✅ SSL provisioned (green checkmark)

### 4. Test Domain
```bash
ping starpage.org
```

Should respond from Firebase IP

---

## If Still Getting Error

### Error: "Record name [@] conflicts with another record"

**Try these steps:**

1. **Refresh the page** (registrar page)
   - Sometimes UI doesn't update immediately

2. **Wait 5 minutes** before trying again
   - DNS propagation takes time

3. **Use a different approach:**
   - Instead of editing, delete the record completely
   - Wait 1 minute
   - Add it fresh as new record

4. **Contact registrar support**
   - If error persists, they can help identify the conflict
   - Provide them this information:
     ```
     Domain: starpage.org
     Record Type: A
     Name: @ (root domain)
     Value: [Firebase provided IP]
     ```

---

## Quick Reference Table

| Issue | Solution |
|-------|----------|
| Multiple A records | Delete duplicates, keep Firebase IP |
| A + CNAME conflict | Delete CNAME, keep A record |
| A + ALIAS conflict | Delete ALIAS, use A record |
| Old stale records | Delete them |
| Firebase IP changed | Update A record with new IP |
| Domain not resolving | Check nslookup result matches Firebase IP |
| SSL still not working | May need 24-48 hours after DNS fix |

---

## Next Steps

1. ✅ Delete conflicting records
2. ✅ Add correct A and AAAA records with Firebase IPs
3. ✅ Wait 5-15 minutes for DNS propagation
4. ✅ Verify with `nslookup starpage.org`
5. ✅ Check Firebase Console for green checkmarks
6. ✅ Deploy: `firebase deploy --only hosting`
7. ✅ Access: https://starpage.org

---

## Need Help?

- **Firebase Hosting Docs**: https://firebase.google.com/docs/hosting/custom-domain
- **DNS Checker**: https://mxtoolbox.com/
- **Registrar Support**: Contact your domain registrar's support team
