# Firebase Hosting Custom Domain Setup - starpage.org

**Project**: Starpage App  
**Domain**: starpage.org  
**Firebase Project**: starpage-ed409  
**Current Setup**: Firebase Hosting configured in firebase.json

---

## 🎯 What This Guide Covers

This guide will help you:
1. Connect your domain `starpage.org` to Firebase Hosting
2. Verify domain ownership via DNS
3. Enable SSL/HTTPS automatically
4. Deploy your web app to the custom domain

---

## Part 1: Prerequisites

### What You'll Need

- ✅ Firebase project created (`starpage-ed409`)
- ✅ Firebase Hosting enabled
- Domain ownership or access: `starpage.org`
- ✅ Access to domain registrar (where domain is registered)
- ✅ Firebase CLI installed locally
- ✅ Flutter web build ready

### Prerequisites Checklist

```powershell
# Verify Firebase CLI installed
firebase --version

# Login to Firebase
firebase login

# List your projects
firebase projects:list

# Should show: starpage-ed409 (or your project ID)
```

---

## Part 2: Add Domain to Firebase Console

### Step 1: Go to Firebase Console

1. Open: https://console.firebase.google.com
2. Select project: **starpage-ed409**
3. Left menu → **Hosting**
4. Click **Hosting** (if not already selected)

### Step 2: Connect Domain

1. Click **Connect Domain** button (or **Add custom domain**)
2. Enter your domain: `starpage.org`
3. Click **Continue**
4. Firebase verifies domain availability

### Step 3: Verify Domain Ownership

Firebase will show you two options:

#### Option A: Verify with DNS Records (Recommended)
```
Type: TXT
Name: _acmechallenge.starpage.org
Value: [Long string Firebase provides]
TTL: 3600 (or default)
```

#### Option B: Verify with HTML File
Upload HTML file to your hosting (less common for custom domains)

**→ We'll use Option A (DNS Records)**

---

## Part 3: DNS Configuration

### Where to Find Your Domain Registrar

Your domain `starpage.org` is registered at one of these:
- GoDaddy
- Namecheap
- Google Domains
- CloudFlare
- AWS Route 53
- Other registrar

**You need to access the DNS records for your domain.**

### Step-by-Step DNS Setup

#### For Google Domains
1. Go to: https://domains.google.com
2. Click your domain: `starpage.org`
3. Left menu → **DNS**
4. Scroll to **Custom records**
5. Click **+ Create Record**
6. Fill in:
   - Type: **TXT**
   - Name: **_acmechallenge**
   - Value: [Paste Firebase provided value]
   - TTL: **3600**
7. Click **Create**

#### For Namecheap
1. Go to: https://www.namecheap.com/dashboard
2. Click **Domain List**
3. Click **Manage** for `starpage.org`
4. Go to **Advanced DNS** tab
5. Click **+ Add Record**
6. Select Type: **TXT Record**
7. Host: **_acmechallenge**
8. Value: [Paste Firebase provided value]
9. TTL: **3600**
10. Click checkmark to save

#### For GoDaddy
1. Go to: https://www.godaddy.com/domains
2. Select `starpage.org`
3. Click **Manage DNS**
4. Click **+ Add** → **TXT**
5. Name: **_acmechallenge**
6. Data: [Paste Firebase provided value]
7. TTL: **3600**
8. Click **Save**

#### For CloudFlare
1. Go to: https://dash.cloudflare.com
2. Select your domain zone
3. Go to **DNS** section
4. Click **+ Add record**
5. Type: **TXT**
6. Name: **_acmechallenge.starpage.org**
7. Content: [Paste Firebase provided value]
8. TTL: **3600** (or Auto)
9. Click **Save**

#### For AWS Route 53
1. Go to: https://console.aws.amazon.com/route53
2. Click **Hosted zones**
3. Select `starpage.org`
4. Click **Create record**
5. Record type: **TXT**
6. Record name: **_acmechallenge**
7. Record value: [Paste Firebase provided value]
8. TTL: **3600**
9. Click **Create records**

---

## Part 4: Firebase Domain Verification

### Verify in Firebase Console

1. In Firebase Hosting → **Connect Domain** dialog
2. After adding DNS TXT record, wait 5-10 minutes
3. Click **Verify** button in Firebase Console
4. Firebase checks DNS records

### Verification Timeframe

```
Time Required for DNS Propagation:
│
├─ Immediately: Record added to registrar
│
├─ 5-10 minutes: DNS propagates globally
│
├─ 15-30 minutes: Firebase verifies
│
└─ Done! ✅ Domain verified
```

---

## Part 5: Configure A and AAAA Records

After TXT verification, Firebase shows you additional records:

### Firebase IP Addresses

Firebase provides you with:
- **A Record** (IPv4): Points to Firebase server IP
- **AAAA Record** (IPv6): Points to Firebase server IP

### Add A Record (IPv4)

**Name**: `starpage.org` (or @ symbol)  
**Type**: **A**  
**Value**: [Firebase provided IPv4 address]  
**TTL**: **3600**

**Steps vary by registrar:**

#### Google Domains
1. DNS → Custom records
2. + Create Record
3. Type: **A**
4. Name: **@** (root domain)
5. IPv4: [Firebase provided IP]
6. TTL: **3600**
7. Create

#### Namecheap
1. Advanced DNS tab
2. + Add Record
3. Type: **A Record**
4. Host: **@**
5. Value: [Firebase provided IP]
6. TTL: **3600**
7. Save

#### GoDaddy
1. Manage DNS
2. + Add → **A**
3. Name: **@**
4. Data: [Firebase provided IP]
5. TTL: **3600**
6. Save

### Add AAAA Record (IPv6)

**Same process but:**
- Type: **AAAA**
- Value: [Firebase provided IPv6 address]
- Rest same as A record

---

## Part 6: SSL/HTTPS Certificate

Firebase automatically handles SSL/HTTPS:

### Automatic SSL Configuration

1. **Firebase manages SSL certificates**
   - Uses Let's Encrypt
   - Auto-renews before expiration
   - No action needed from you

2. **Certificate Types**
   - Self-signed initially
   - Real certificate issued within 15-24 hours
   - Valid for 1 year (auto-renews)

3. **Enable HTTPS Redirect** (optional)
   - Firebase Console → Hosting
   - Your domain → Edit
   - Enable "Redirect to HTTPS"

### HTTPS Status

Wait 24 hours for full certificate:
- Initially: HTTPS with temporary certificate
- After 24 hours: HTTPS with Let's Encrypt certificate
- Thereafter: Automatic renewal

---

## Part 7: Deploy to Custom Domain

### Deploy Using Firebase CLI

```powershell
# 1. Build Flutter web
flutter build web --release

# 2. Deploy to Firebase Hosting
firebase deploy --project starpage-ed409

# 3. Deployment completes
# Result: Your app available at https://starpage.org
```

### Deploy Using GitHub Actions

Already configured in your project!

```powershell
# Push to main branch
git push origin main

# GitHub Actions automatically:
# 1. Builds Flutter web
# 2. Deploys to Firebase Hosting
# 3. Available at https://starpage.org in ~2-3 minutes
```

---

## Part 8: Verify Domain Setup

### Check Domain Status in Firebase Console

1. Firebase Console → **Hosting**
2. Your domain should show:
   - ✅ Verified
   - ✅ SSL Certificate Active
   - ✅ Serving from custom domain

### Test Your Domain

**In browser:**
```
https://starpage.org
```

**Expected result:**
- Page loads successfully
- HTTPS works (lock icon visible)
- Your Flutter web app displays

### Verify SSL Certificate

**Command line:**
```powershell
# Test SSL certificate
curl -I https://starpage.org

# Should show: HTTP/2 200 or HTTP/1.1 200
# And SSL certificate info
```

---

## Part 9: Configure Domain Settings

### Optional: Redirect www subdomain

If users visit `www.starpage.org`, redirect to main domain:

**Firebase Console → Hosting:**
1. Click your domain
2. Edit
3. Enable "Redirect trailing slash" (if needed)
4. Enable "HTTPS redirect"

### Optional: Configure Rewrites

Already in `firebase.json`:
```json
{
  "hosting": {
    "public": "build/web",
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  }
}
```

This routes all requests to `index.html` for SPA routing.

---

## Part 10: Complete Setup Checklist

### Domain Registration
- [ ] Domain `starpage.org` registered
- [ ] Registrar account accessible
- [ ] DNS management available

### Firebase Console
- [ ] Hosting enabled
- [ ] Domain added via "Connect Domain"
- [ ] TXT record displayed

### DNS Configuration
- [ ] TXT record added to registrar
- [ ] DNS propagated (5-10 min)
- [ ] TXT record verified in Firebase
- [ ] A record added to registrar
- [ ] AAAA record added to registrar
- [ ] DNS propagated again (5-10 min)

### Deployment
- [ ] Flutter web builds successfully
- [ ] Deployed to Firebase Hosting
- [ ] Available at `https://starpage.org`

### Verification
- [ ] Domain loads in browser
- [ ] HTTPS works (green lock icon)
- [ ] App displays correctly
- [ ] SSL certificate active

---

## Part 11: Troubleshooting

### Problem: Domain Not Resolving

**Cause**: DNS records not propagated

**Solution**:
```powershell
# Check DNS propagation
nslookup starpage.org

# Should show: Firebase IP address
# If showing old IP: Wait 24-48 hours for propagation
```

### Problem: SSL Certificate Not Active

**Cause**: Certificate still being issued

**Solution**:
- Wait 24 hours for Let's Encrypt certificate
- Check Firebase Console for status
- It shows as "Processing" initially

### Problem: HTTPS Not Working

**Cause**: Certificate or redirect not configured

**Solution**:
1. Check Firebase Console
2. Verify certificate is active (not "Processing")
3. Enable HTTPS redirect in domain settings
4. Wait 24 hours if certificate is new

### Problem: App Not Loading at Custom Domain

**Cause**: Deployment not complete or rewrites not configured

**Solution**:
```powershell
# Redeploy
firebase deploy --project starpage-ed409

# Check firebase.json has rewrites for SPA
# See Part 9 above
```

### Problem: Wrong Content Showing

**Cause**: Browser cache or old DNS

**Solution**:
```powershell
# Clear browser cache (Ctrl+Shift+Delete)
# Or use incognito/private mode
# Wait 24 hours for DNS cache clear
```

---

## Part 12: Post-Setup Monitoring

### Monitor Hosting Performance

1. Firebase Console → **Hosting**
2. Click your domain
3. View **Analytics**:
   - Traffic stats
   - Page load times
   - Error rates

### Monitor SSL Certificate

1. Firebase Console → **Hosting**
2. Click your domain
3. Check SSL status:
   - ✅ Active
   - Renewal date

### View Deployment History

1. Firebase Console → **Hosting**
2. **Deployment History** tab
3. See all previous deployments
4. Rollback if needed

---

## Part 13: Custom Domain Advanced Configuration

### Set Up Subdomain (Optional)

To use subdomain like `app.starpage.org`:

1. In Firebase Console → Add another domain
2. Enter: `app.starpage.org`
3. Repeat DNS verification
4. Can serve different content per subdomain

### Configure Cache Headers

Already in `firebase.json`:
```json
"headers": [
  {
    "source": "**/*.@(js|css)",
    "headers": [{
      "key": "Cache-Control",
      "value": "max-age=31536000"
    }]
  }
]
```

### Add Security Headers

Add to `firebase.json`:
```json
"headers": [
  {
    "source": "**",
    "headers": [
      {
        "key": "X-Content-Type-Options",
        "value": "nosniff"
      },
      {
        "key": "X-Frame-Options",
        "value": "SAMEORIGIN"
      }
    ]
  }
]
```

---

## Quick Reference Summary

```
┌─ Domain Setup Timeline
│
├─ Minutes 0-5: Add TXT record to DNS
├─ Minutes 5-10: DNS propagates
├─ Minutes 10-15: Firebase verifies
├─ Minutes 15: Add A & AAAA records
├─ Minutes 15-25: DNS propagates again
├─ Minutes 25: Deploy to Firebase
├─ Minutes 25-27: Deployment completes
├─ Minutes 27-1440: SSL cert issued
│
└─ Hours 24+: Full setup complete ✅
```

---

## Commands Reference

```powershell
# Build Flutter web
flutter build web --release

# Deploy to Firebase
firebase deploy --project starpage-ed409

# Deploy specific target
firebase deploy --only hosting --project starpage-ed409

# Check deployment status
firebase hosting:channel:list --project starpage-ed409

# View hosting info
firebase hosting:sites:list --project starpage-ed409

# Test locally
firebase serve --project starpage-ed409
```

---

## Support Resources

- **Firebase Hosting Docs**: https://firebase.google.com/docs/hosting
- **Custom Domain Setup**: https://firebase.google.com/docs/hosting/custom-domain
- **DNS Configuration**: https://firebase.google.com/docs/hosting/custom-domain#set_up_your_domain
- **Troubleshooting**: https://firebase.google.com/docs/hosting/troubleshooting

---

## Next Steps

1. **Access your domain registrar**
   - GoDaddy, Namecheap, Google Domains, etc.

2. **In Firebase Console**
   - Click "Connect Domain"
   - Enter: `starpage.org`
   - Note the TXT record

3. **Add DNS Records**
   - TXT record for verification
   - A record (IPv4)
   - AAAA record (IPv6)

4. **Wait for Verification**
   - 5-10 minutes for propagation
   - Firebase verifies automatically

5. **Deploy**
   - `firebase deploy --project starpage-ed409`
   - Or push to main branch (auto-deploys)

6. **Verify**
   - Visit: `https://starpage.org`
   - Check green lock icon
   - Test functionality

---

**Your domain `starpage.org` will be live on Firebase Hosting within 30 minutes!**

