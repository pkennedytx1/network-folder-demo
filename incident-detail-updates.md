# Incident Detail Page Updates

## Overview
Updated the incident detail page with improved "Involved Persons" section and Amazon Location Services map integration.

## File Location
`/Users/patrick.kennedy/Desktop/Apricot_Files/whiteboarding/network-document-folder/incident-detail-updated.html`

---

## Key Changes

### 1. ✅ Involved Persons - Table Format (Like Participants Page)

**Before:**
- Simple list with avatar + name
- Minimal information
- No row-level details

**After:**
- Full data table with columns:
  - **Participant** - Avatar, name, and ID (P-1042)
  - **Role in Incident** - Color-coded badges (Victim, Witness, At Risk, Aggressor)
  - **Organizations** - List of all orgs working with this person
  - **Last Contact** - Type and timestamp
  - **Age** - Participant age
  - **Actions** - View/Edit buttons

**Features:**
- Hover effect on rows
- Clickable action buttons
- Multiple participants shown
- Organization associations displayed with mini icons

**Example Row:**
```
[DW Avatar] DeShawn Williams    [Victim]    • Peacemakers Austin      Hospital Visit     19    [👁️] [✏️]
            P-1042                          • Trauma-Informed Care   2 hours ago
```

---

### 2. ✅ Amazon Location Services Map

**Features:**
- 400px height map container
- Styled to match AWS Location Service aesthetic
- Red location marker at incident site
- Map controls (zoom in/out, recenter)
- Location info box showing address
- Amazon Location Service attribution

**Visual Design:**
- Gradient background (teal-green for map tiles)
- Custom red pin marker with white center
- Floating white control buttons (top-right)
- Info box with incident address (bottom-left)
- "© Amazon Location Service" attribution (top-left)

**Interactive Elements:**
- Zoom in/out buttons (+ and -)
- Recenter button (location arrow icon)
- Info box shows:
  - Street name: "E. William Cannon Dr."
  - Area: "Dove Springs, Austin, TX 78744"

---

## Role Badges (Color-Coded)

```css
Victim    → Red (#dc2626)
Witness   → Blue (#3b82f6)
At Risk   → Yellow (#eab308)
Aggressor → Orange (#ea580c)
```

These match incident severity colors for visual consistency.

---

## Organization Icons

Mini org badges in the Organizations column:
- 20×20px squares
- 2-letter abbreviations (PA, TC, SO, YS)
- Gray background by default
- Can be color-coded per org in future

---

## Table Structure Benefits

### Advantages over simple list:
1. **Scannable** - Quick overview of all involved persons
2. **Sortable** - Columns can be sorted (future enhancement)
3. **Filterable** - Can filter by role (future enhancement)
4. **Consistent** - Matches participants page and orgs page
5. **Actionable** - View/Edit buttons for each person
6. **Informative** - Shows relationships and recent activity

### Data Shown:
- **Participant identity** - Name, ID, avatar
- **Incident role** - Why they're involved
- **Support network** - Which orgs are helping
- **Recent activity** - Last contact type and time
- **Demographics** - Age for context
- **Quick actions** - View details or edit

---

## Map Integration Notes

### Why Amazon Location Service?
- AWS-native solution (already using AWS infrastructure)
- HIPAA compliant (important for participant data)
- Cost-effective ($4/1000 requests)
- Integration with AWS Cognito for auth
- No Google Maps API key needed

### Implementation Considerations:
1. **API Key Management**
   - Store in AWS Secrets Manager
   - Rotate keys quarterly
   - Restrict to production domains

2. **Data Privacy**
   - Don't store exact addresses in map
   - Use general area (street-level, not house number)
   - Blur markers if needed

3. **Performance**
   - Lazy load map (only when incident detail opened)
   - Cache tile requests
   - Limit zoom levels (city/street only, not satellite)

4. **Accessibility**
   - Keyboard navigation for map controls
   - Screen reader support for location info
   - Alt text for map marker

---

## Code Structure

### HTML Organization:
```html
<div class="map-section">
  <div class="description-title">Incident Location</div>
  <div class="map-container">
    <div class="map-placeholder">
      <!-- Marker -->
      <div class="map-marker"></div>

      <!-- Controls -->
      <div class="map-controls">
        <button>+</button>
        <button>-</button>
        <button>↻</button>
      </div>

      <!-- Attribution -->
      <div class="map-legend">© Amazon Location Service</div>

      <!-- Info Box -->
      <div class="map-info-box">
        <div>Street Name</div>
        <div>Area, City, State ZIP</div>
      </div>
    </div>
  </div>
</div>
```

### CSS Highlights:
- `.map-container` - Fixed height, overflow hidden
- `.map-placeholder` - Gradient background (simulates tiles)
- `.map-marker` - Teardrop shape via CSS transform
- `.map-controls` - Absolute positioned, stacked vertically
- `.map-info-box` - Floating white card, bottom-left

---

## Responsive Behavior

### Desktop (>768px):
- Map: 400px height
- Table: All columns visible
- Actions: Icon buttons with hover states

### Mobile (<768px):
- Map: 300px height (shorter for screen space)
- Table: Stacked card layout (future enhancement)
- Actions: Full-width buttons

---

## Future Enhancements

### Table Features:
1. **Sorting** - Click column headers to sort
2. **Filtering** - Filter by role or organization
3. **Search** - Search by participant name
4. **Pagination** - If >10 involved persons
5. **Export** - Download table as CSV

### Map Features:
1. **Real Amazon Location Service API** - Replace placeholder
2. **Multiple incidents** - Show nearby incidents as pins
3. **Heatmap** - Show incident density over time
4. **Drawing tools** - Highlight areas for safety planning
5. **Street view** - Link to ground-level imagery

### Integration:
1. **Click participant** - Jump to their detail page
2. **Click org icon** - Show org contact info tooltip
3. **Timeline** - Show incident timeline with contacts
4. **Notes** - Add notes directly from table row

---

## Design Rationale

### Why table format for involved persons?
- **Consistency** - Matches rest of app (orgs page, participants page)
- **Information density** - More data in less space
- **Professional** - Standard enterprise UX pattern
- **Accessible** - Screen readers handle tables well
- **Flexible** - Easy to add/remove columns

### Why dedicated map section?
- **Visual context** - Location is critical for incident response
- **Coordination** - Helps orgs plan coverage areas
- **Safety** - Identify high-risk zones
- **Compliance** - May be required for reporting
- **Credibility** - Professional incident management tool

---

## Testing Checklist

### Visual QA:
- [ ] Table columns align correctly
- [ ] Role badges display with correct colors
- [ ] Map marker is centered
- [ ] Map controls are clickable
- [ ] Org icons show 2-letter codes
- [ ] Last contact timestamps are relative

### Functional QA:
- [ ] Click participant name → goes to detail
- [ ] Click view icon → opens participant modal
- [ ] Click edit icon → opens edit form
- [ ] Map zoom buttons work
- [ ] Table rows have hover effect
- [ ] Responsive on mobile

### Accessibility QA:
- [ ] Keyboard navigation works
- [ ] Screen reader announces table headers
- [ ] Color contrast meets WCAG AA
- [ ] Focus indicators visible
- [ ] Alt text for icons

---

## Next Steps

1. **Integrate into main demo** - Replace old involved persons section
2. **Add real map API** - Connect Amazon Location Service
3. **Add interactivity** - Make table sortable/filterable
4. **Test with real data** - Use actual incident records
5. **Mobile optimization** - Test on small screens
6. **Performance testing** - Measure load times

---

## Questions for Product Team

1. Should we show participant photos instead of initials?
2. Should "At Risk" participants be highlighted differently?
3. Should we show participant home addresses (privacy concern)?
4. Should orgs be able to add/remove involved persons?
5. Should we track who added each person to the incident?
6. Should we show why each person is marked "at risk"?

---

## Related Files

- Original demo: `_includes/network-folder-demo.html`
- Updated version: `incident-detail-updated.html` (this file)
- Styles: Inline in `<style>` tag (can be extracted to `styles.css`)
- JavaScript: None required for static demo

---

**Status**: ✅ Demo UI complete, ready for review
**Next**: Integrate Amazon Location Service API
