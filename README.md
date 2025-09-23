# Blaze’s Roblox Scripting Portfolio

👋 Hi! I’m **Blaze**, a Roblox scripter with 1–2 years of experience.  
I specialize in **short-term scripting projects** (1–4 days) and focus on functional systems rather than GUI.

Check out my scripts below:

---

## 📂 Leaderstats
**PlayerCoinsDataStore.lua**  
- Handles player coins using DataStore.  
- Saves and loads player coins when they join/leave the game.  
- Initializes leaderstats folder with default coin value.

---

## 📂 Remotes
**PlayerCoinsRemoteHandler.lua**  
- Manages RemoteEvents for adding and spending coins.  
- Touching a coin part adds coins, and spending parts subtract coins.  
- Works seamlessly with the Leaderstats system.

---

## 📂 Tools
**RaycastGun.lua**  
- Implements a raycasting gun system.  
- Headshots deal higher damage than body shots.  
- Uses server-side RemoteEvents for secure firing logic.

**SwordTool.lua** *(if applicable)*  
- Gives players a sword tool.  
- Handles damage detection for hits.

---

## 📂 Monetization
**GamepassAndPurchaseHistory.lua**  
- Handles Gamepass ownership checks.  
- Tracks purchase history for players.  
- Grants Gamepass features upon purchase.

**DeveloperProductHandler.lua**  
- Handles developer product purchases.  
- Gives players items or tools (e.g., sword) after purchase.  
- Integrates with MarketplaceService ProcessReceipt system.

---
