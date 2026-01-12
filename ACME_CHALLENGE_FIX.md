# ACME Challenge Failure - SSL Certificate Issue

## Error Message
```
One or more of Hosting's HTTP GET request for the ACME challenge failed:
- 15.197.225.128: 404 Not Found
- 2a04:4e42:200::199: Request failed
- 2a04:4e42:400::199: Request failed
- 2a04:4e42:600::199: Request failed
- 2a04:4e42::199: Request failed
- 3.33.251.168: 404 Not Found
```

---

## What This Means

Firebase Hosting attempted to validate your custom domain (`starpage.org`) by requesting the ACME challenge file at:
```
http://starpage.org/.well-known/acme-challenge/[token]
```

This request received **404 Not Found** errors, preventing SSL certificate issuance.

---

## Root Cause - FIXED ✅

The `firebase.json` contained a problematic rewrite rule:

```json
// ❌ WRONG - Blocked ACME challenge verification
"rewrites": [
  {
    "source": "/.well-known/**",
    "destination": "/.well-known/index.html"
  },
  {
    "source": "**",
    "destination": "/index.html"
  }
]
```

This rewrite was redirecting ACME challenge requests to `/index.html`, which doesn't exist, causing 404 errors.

### Fix Applied ✅
Removed the problematic `.well-known` rewrite rule. Firebase Hosting now allows ACME requests to pass through.

```json
// ✅ CORRECT - Allows ACME challenge verification
"rewrites": [
  {
    "source": "**",
    "destination": "/index.html"
  }
]
```

---

## Next Steps to Complete SSL Setup

### 1. Verify DNS Configuration
Your domain registrar should have these DNS records pointing to Firebase:

```
A Record:
  Host: @
  Value: 199.36.158.100  (or Firebase-assigned IP)

OR use CNAME (for subdomains):
  Host: www
  Value: flutter-stars-web--starpage-ed409.web.app
```

### 2. Verify in Firebase Console

1. Go to **Firebase Console** → **Hosting** → **Custom domains**
2. Click on your domain `starpage.org`
3. Check **Domain status**:
   - ✅ Connected (DNS verified)
   - ✅ SSL provisioned (green checkmark)

### 3. Redeploy to Trigger SSL

```bash
# Build web
flutter build web --release

# Deploy to Firebase Hosting
firebase deploy --only hosting
```

After deployment, Firebase will attempt ACME validation again.

### 4. Wait for DNS Propagation

DNS changes can take 5 minutes to 48 hours to propagate globally.

**Check DNS status:**
```bash
# Windows
nslookup starpage.org

# Mac/Linux
dig starpage.org
```

Expected output: Should resolve to Firebase IP (199.36.158.100 or similar)

---

## Troubleshooting

### Still Getting 404 Errors?

**Check if DNS is properly configured:**
```bash
# Verify domain points to Firebase
nslookup starpage.org

# Should show Firebase IP address
```

**If DNS is NOT pointing to Firebase:**
1. Go to your domain registrar (GoDaddy, Namecheap, etc.)
2. Update A record to Firebase IP: `199.36.158.100`
3. Wait 15-30 minutes for propagation
4. Redeploy: `firebase deploy --only hosting`

**If DNS IS correct but still failing:**
1. Clear browser cache
2. Wait a few minutes
3. Try accessing domain from incognito/private window
4. Contact Firebase Support with:
   - Domain name
   - Project ID (starpage-ed409)
   - Error timestamp

### Verify Firebase is Serving ACME Challenges

```bash
# Test if Firebase can serve the domain
curl -v http://starpage.org/

# Should respond (not 404)
```

---

## Prevention - Best Practices

✅ **Never rewrite `/.well-known/`** - This breaks SSL validation
✅ **Keep ACME paths open** - Firebase needs HTTP access to validate
✅ **Use only necessary rewrites** - Only rewrite SPA routes (e.g., `/app/**`)
✅ **Test before deploying** - Run `firebase serve` locally first

---

## Current Configuration (FIXED)

**File**: `firebase.json`

```json
{
  "hosting": {
    "public": "build/web",
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ],
    "cleanUrls": true,
    "trailingSlashBehavior": "REMOVE",
    "errorPage": "/404.html"
  }
}
```

✅ This configuration:
- Serves your Flutter web app from `build/web`
- Allows ACME challenge verification (no `.well-known` rewrite)
- Rewrites SPA routes to `index.html`
- Cleans up URLs (removes `.html` extensions)

---

## Summary

| Step | Status | Action |
|------|--------|--------|
| 1. Remove `.well-known` rewrite | ✅ Done | Configuration fixed |
| 2. Verify DNS pointing to Firebase | ⏳ Verify | Check with registrar |
| 3. Redeploy to Firebase | ⏳ Do | `firebase deploy --only hosting` |
| 4. Wait for SSL provisioning | ⏳ Wait | 5-30 minutes typically |
| 5. Verify SSL certificate | ⏳ Check | HTTPS should work |

---

## Need Help?

1. **Verify your current DNS**: https://mxtoolbox.com/
2. **Check Firebase Hosting status**: Firebase Console → Hosting
3. **Review Firebase Hosting docs**: https://firebase.google.com/docs/hosting/custom-domain
4. **Contact Firebase Support**: If issues persist after 1 hour
