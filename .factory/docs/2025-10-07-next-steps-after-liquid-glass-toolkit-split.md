## Proposed Next Steps

1. **Complete Glass API Adoption Audit**  
   - Grep for any remaining `Material`, legacy `liquidGlass`, or ad-hoc overlays in `Presentation/Views/**`.  
   - Enumerate views still mixing custom styling with `.glassEffect()` and prioritize high-traffic screens (Library, Now Playing extras, Settings).  
   - Produce a migration checklist noting blockers (e.g., bespoke gradients, performance constraints).  

2. **Refactor Priority Views to New Toolkit**  
   - For each targeted view, replace bespoke glass code with `glassSurface`, `GlassButton`, and other helpers.  
   - Ensure matched geometry / transitions keep using `GlassEffectContainer` semantics and update previews to leverage `GlassShowcase` patterns.  
   - Validate accessibility flows (Reduce Transparency, Differentiate Without Color) per view during the refactor.

3. **Expand Automated Coverage for Glass Utilities**  
   - Add unit tests or SwiftUI snapshot tests covering `glassSurface` tint decisions, `GlassPerformanceProfiler` metrics handling, and `BatteryOptimizedGlassUtilities`.  
   - Include targeted UI preview tests for particle toggling and adaptive glass to guard regressions.  

4. **Integrate Tooling and Documentation Updates**  
   - Update any remaining developer references (STATUS.md, design notes) to the new `Glass*` modules.  
   - Add a brief migration guide in the internal docs describing how to convert a legacy glass view using the new toolkit.  
   - Capture `make lint` / `make test` outputs in STATUS or PR notes for traceability once the above refactors land.