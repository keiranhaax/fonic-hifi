# data-analysis.md
Trend algorithms, visualization patterns, and health metrics correlation for iOS health apps

## Trend Analysis Algorithms
- **Moving Averages**: 7-day SMA for short-term trends, 21-day EMA for long-term patterns
- **SARIMA Models**: Seasonal health data forecasting with real-time anomaly detection
- **STL Decomposition**: Breaks time series into trend, seasonal, and residual components
- **Z-Score Analysis**: Statistical outlier detection for abnormal vital signs
- **Isolation Forest**: Unsupervised anomaly detection without labeled datasets

## Health Metrics Correlation
- **Cardiovascular**: Heart rate ↔ HRV ↔ blood pressure ↔ activity levels
- **Activity Patterns**: Steps ↔ sleep quality ↔ mood indicators ↔ energy levels  
- **Metabolic Health**: Blood glucose ↔ meal timing ↔ exercise intensity
- **Cross-Modal Analysis**: LSTM networks for multi-metric dependencies
- **Correlation Threshold**: 7,662 significant correlations across 221 health indicators

## Swift Charts for Health Visualization
- **LinePlot**: Health trends (heart rate over time, blood pressure patterns)
- **AreaPlot**: Cumulative data (sleep patterns, activity zones throughout day)
- **BarPlot**: Discrete metrics (daily steps, workout counts, medication adherence)
- **Interactive Features**: Selection, scrolling, real-time updates with Combine
- **iOS 18 Vectorized Plots**: Efficient rendering for large health datasets (1000+ points)

## Core ML for Health Analytics
- **On-Device Processing**: Privacy-preserving health insights without cloud upload
- **Health Sensor Analysis**: Activity recognition, sleep stage classification
- **Custom Models**: Create ML for personalized health pattern recognition
- **Real-Time Inference**: Background health monitoring with <100ms latency
- **13x Performance Boost**: iOS 18 Core ML optimizations for health apps

## Performance Optimization
- **Batch Processing**: 1,000-5,000 health records for optimal performance
- **Background Analysis**: Actor isolation for thread-safe health computations
- **Memory Management**: Stream processing for large datasets to prevent spikes
- **Battery Awareness**: Adaptive analysis frequency based on device state

## Health Score Calculations
- **Weighted Scoring**: Assign importance weights (heart health: 40%, activity: 30%, sleep: 30%)
- **Normalized Scaling**: 0-100 scale across different metric types and units
- **Temporal Weighting**: Recent measurements weighted higher (last 7 days: 50%)
- **Personal Baselines**: Individual variations and goal-adjusted scoring

## Statistical Analysis Patterns
- **Data Validation**: Range checks, unit verification, source quality assessment
- **Missing Data**: Interpolation strategies for gaps in health monitoring
- **Confidence Intervals**: Statistical significance for health trend changes
- **Outlier Handling**: Median filters for sensor noise, validation for extreme values

## Implementation Patterns
```swift
// Health trend calculation with async/await
actor HealthTrendAnalyzer {
    func calculateMovingAverage(data: [HealthMetric], window: Int) async -> [Double] {
        // SMA calculation with efficient memory usage
    }
    
    func detectAnomalies(metrics: [HealthMetric]) async -> [HealthAnomaly] {
        // Z-score analysis with personal baseline adjustment
    }
}

// Real-time chart updates with Combine
class HealthChartViewModel: ObservableObject {
    @Published var chartData: [ChartDataEntry] = []
    
    func updateChart(with newData: [HealthMetric]) {
        // SwiftUI Chart integration with smooth animations
    }
}
```

## Health Data Processing Pipeline
1. **Collection**: HealthKit queries with proper error handling
2. **Validation**: Range checks, unit conversion, quality scoring
3. **Analysis**: Trend calculation, correlation detection, anomaly identification
4. **Visualization**: Swift Charts with interactive exploration
5. **Insights**: Personalized recommendations based on patterns

## Core ML Health Models
- **Activity Classification**: Exercise type detection from motion sensors
- **Sleep Analysis**: Sleep stage classification from heart rate and movement
- **Anomaly Detection**: Health pattern deviation from personal baselines
- **Trend Prediction**: Forecasting health metric changes based on patterns