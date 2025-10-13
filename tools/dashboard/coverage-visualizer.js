/**
 * Coverage Visualizer
 * Handles coverage data visualization and interactive charts
 */

class CoverageVisualizer {
  constructor() {
    this.charts = new Map();
    this.data = null;
    this.config = {
      colors: {
        high: "#28a745", // Green for >= 90%
        medium: "#ffc107", // Yellow for >= 70%
        low: "#dc3545", // Red for < 70%
        primary: "#007bff",
      },
      thresholds: {
        high: 90,
        medium: 70,
      },
    };
  }

  // Initialize visualizer with coverage data
  init(coverageData) {
    this.data = coverageData;
    this.renderOverviewCharts();
    this.renderFileHeatmap();
    this.renderTrendChart();
    this.renderCoverageBreakdown();
  }

  // Render overview charts (summary statistics)
  renderOverviewCharts() {
    if (!this.data || !this.data.summary) {
      return;
    }

    const summary = this.data.summary;

    // Overall coverage donut chart
    this.renderDonutChart("overallCoverageChart", {
      title: "Overall Coverage",
      data: [
        { label: "Covered", value: summary.coveredLines, color: this.config.colors.high },
        { label: "Uncovered", value: summary.totalLines - summary.coveredLines, color: this.config.colors.low },
      ],
    });

    // Function coverage chart
    this.renderDonutChart("functionCoverageChart", {
      title: "Function Coverage",
      data: [
        { label: "Covered", value: summary.coveredFunctions, color: this.config.colors.high },
        { label: "Uncovered", value: summary.totalFunctions - summary.coveredFunctions, color: this.config.colors.low },
      ],
    });

    // Coverage distribution histogram
    this.renderCoverageDistribution();
  }

  // Render donut chart
  renderDonutChart(canvasId, config) {
    const canvas = document.getElementById(canvasId);
    if (!canvas) {
      return;
    }

    const ctx = canvas.getContext("2d");

    if (this.charts.has(canvasId)) {
      this.charts.get(canvasId).destroy();
    }

    const chart = new Chart(ctx, {
      type: "doughnut",
      data: {
        labels: config.data.map(d => d.label),
        datasets: [
          {
            data: config.data.map(d => d.value),
            backgroundColor: config.data.map(d => d.color),
            borderWidth: 2,
            borderColor: "#fff",
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          title: {
            display: true,
            text: config.title,
            font: { size: 16, weight: "bold" },
          },
          legend: {
            position: "bottom",
            labels: { padding: 15 },
          },
          tooltip: {
            callbacks: {
              label: context => {
                const total = context.dataset.data.reduce((a, b) => a + b, 0);
                const percentage = ((context.raw / total) * 100).toFixed(1);
                return `${context.label}: ${context.raw} (${percentage}%)`;
              },
            },
          },
        },
        cutout: "60%",
      },
    });

    this.charts.set(canvasId, chart);
  }

  // Render file coverage heatmap
  renderFileHeatmap() {
    const container = document.getElementById("coverageHeatmap");
    if (!container || !this.data || !this.data.files) {
      return;
    }

    const files = this.data.files;
    let heatmapHTML = '<div class="heatmap-container">';

    // Sort files by coverage (lowest first to highlight issues)
    const sortedFiles = [...files].sort((a, b) => a.lines.percentage - b.lines.percentage);

    sortedFiles.forEach(file => {
      const coverage = file.lines.percentage;
      const className = this.getCoverageClass(coverage);
      const fileName = file.path.split("/").pop();
      const shortPath = this.shortenPath(file.path);

      heatmapHTML += `
                <div class="heatmap-cell ${className}" 
                     data-file="${file.path}" 
                     data-coverage="${coverage.toFixed(1)}"
                     onclick="coverageVisualizer.showFileDetails('${file.path}')">
                    <div class="cell-header">
                        <div class="file-name" title="${file.path}">${fileName}</div>
                        <div class="file-path">${shortPath}</div>
                    </div>
                    <div class="cell-body">
                        <div class="coverage-percentage">${coverage.toFixed(1)}%</div>
                        <div class="coverage-bar">
                            <div class="coverage-fill" style="width: ${coverage}%"></div>
                        </div>
                        <div class="coverage-stats">
                            <span>${file.lines.covered}/${file.lines.total} lines</span>
                        </div>
                    </div>
                </div>
            `;
    });

    heatmapHTML += "</div>";

    // Add legend
    heatmapHTML += this.createHeatmapLegend();

    container.innerHTML = heatmapHTML;
  }

  // Create heatmap legend
  createHeatmapLegend() {
    return `
            <div class="heatmap-legend">
                <div class="legend-title">Coverage Levels</div>
                <div class="legend-items">
                    <div class="legend-item">
                        <div class="legend-color high"></div>
                        <span>High (≥${this.config.thresholds.high}%)</span>
                    </div>
                    <div class="legend-item">
                        <div class="legend-color medium"></div>
                        <span>Medium (≥${this.config.thresholds.medium}%)</span>
                    </div>
                    <div class="legend-item">
                        <div class="legend-color low"></div>
                        <span>Low (<${this.config.thresholds.medium}%)</span>
                    </div>
                </div>
            </div>
        `;
  }

  // Render coverage trend chart
  renderTrendChart() {
    const canvas = document.getElementById("coverageTrendChart");
    if (!canvas || !this.data || !this.data.history) {
      return;
    }

    const ctx = canvas.getContext("2d");

    if (this.charts.has("coverageTrendChart")) {
      this.charts.get("coverageTrendChart").destroy();
    }

    const history = this.data.history;

    const chart = new Chart(ctx, {
      type: "line",
      data: {
        labels: history.dates,
        datasets: [
          {
            label: "Line Coverage",
            data: history.lineCoverage,
            borderColor: this.config.colors.primary,
            backgroundColor: this.config.colors.primary + "20",
            tension: 0.4,
            fill: true,
          },
          {
            label: "Function Coverage",
            data: history.functionCoverage,
            borderColor: this.config.colors.high,
            backgroundColor: this.config.colors.high + "20",
            tension: 0.4,
            fill: false,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          title: {
            display: true,
            text: "Coverage Trend (30 Days)",
            font: { size: 16, weight: "bold" },
          },
          legend: {
            position: "top",
          },
        },
        scales: {
          x: {
            title: {
              display: true,
              text: "Date",
            },
          },
          y: {
            title: {
              display: true,
              text: "Coverage Percentage",
            },
            min: 0,
            max: 100,
            ticks: {
              callback: value => value + "%",
            },
          },
        },
        interaction: {
          intersect: false,
          mode: "index",
        },
      },
    });

    this.charts.set("coverageTrendChart", chart);
  }

  // Render coverage breakdown by category
  renderCoverageBreakdown() {
    const canvas = document.getElementById("coverageBreakdownChart");
    if (!canvas || !this.data || !this.data.breakdown) {
      return;
    }

    const ctx = canvas.getContext("2d");

    if (this.charts.has("coverageBreakdownChart")) {
      this.charts.get("coverageBreakdownChart").destroy();
    }

    const breakdown = this.data.breakdown;

    const chart = new Chart(ctx, {
      type: "bar",
      data: {
        labels: breakdown.categories,
        datasets: [
          {
            label: "Line Coverage",
            data: breakdown.lineCoverage,
            backgroundColor: this.config.colors.primary,
            borderColor: this.config.colors.primary,
            borderWidth: 1,
          },
          {
            label: "Function Coverage",
            data: breakdown.functionCoverage,
            backgroundColor: this.config.colors.high,
            borderColor: this.config.colors.high,
            borderWidth: 1,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          title: {
            display: true,
            text: "Coverage by Category",
            font: { size: 16, weight: "bold" },
          },
          legend: {
            position: "top",
          },
        },
        scales: {
          x: {
            title: {
              display: true,
              text: "Component",
            },
          },
          y: {
            title: {
              display: true,
              text: "Coverage Percentage",
            },
            min: 0,
            max: 100,
            ticks: {
              callback: value => value + "%",
            },
          },
        },
      },
    });

    this.charts.set("coverageBreakdownChart", chart);
  }

  // Render coverage distribution histogram
  renderCoverageDistribution() {
    if (!this.data || !this.data.files) {
      return;
    }

    const buckets = Array(10).fill(0); // 0-10%, 10-20%, ..., 90-100%

    this.data.files.forEach(file => {
      const coverage = file.lines.percentage;
      const bucketIndex = Math.min(Math.floor(coverage / 10), 9);
      buckets[bucketIndex]++;
    });

    const canvas = document.getElementById("distributionChart");
    if (!canvas) {
      return;
    }

    const ctx = canvas.getContext("2d");

    if (this.charts.has("distributionChart")) {
      this.charts.get("distributionChart").destroy();
    }

    const chart = new Chart(ctx, {
      type: "bar",
      data: {
        labels: buckets.map((_, i) => `${i * 10}-${(i + 1) * 10}%`),
        datasets: [
          {
            label: "Number of Files",
            data: buckets,
            backgroundColor: buckets.map((_, i) => {
              if (i >= 9) {
                return this.config.colors.high;
              }
              if (i >= 7) {
                return this.config.colors.medium;
              }
              return this.config.colors.low;
            }),
            borderWidth: 1,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          title: {
            display: true,
            text: "Coverage Distribution",
            font: { size: 16, weight: "bold" },
          },
          legend: {
            display: false,
          },
        },
        scales: {
          x: {
            title: {
              display: true,
              text: "Coverage Range",
            },
          },
          y: {
            title: {
              display: true,
              text: "Number of Files",
            },
            beginAtZero: true,
          },
        },
      },
    });

    this.charts.set("distributionChart", chart);
  }

  // Show detailed file coverage information
  showFileDetails(filePath) {
    const file = this.data.files.find(f => f.path === filePath);
    if (!file) {
      return;
    }

    const modal = this.createFileDetailsModal(file);
    document.body.appendChild(modal);

    // Show modal
    setTimeout(() => modal.classList.add("show"), 10);
  }

  // Create file details modal
  createFileDetailsModal(file) {
    const modal = document.createElement("div");
    modal.className = "modal-overlay";
    modal.innerHTML = `
            <div class="modal-content">
                <div class="modal-header">
                    <h3>Coverage Details: ${file.path}</h3>
                    <button class="modal-close" onclick="this.closest('.modal-overlay').remove()">&times;</button>
                </div>
                <div class="modal-body">
                    <div class="file-stats">
                        <div class="stat-item">
                            <label>Line Coverage:</label>
                            <span class="stat-value">${file.lines.percentage.toFixed(1)}% (${file.lines.covered}/${file.lines.total})</span>
                        </div>
                        <div class="stat-item">
                            <label>Function Coverage:</label>
                            <span class="stat-value">${file.functions.percentage.toFixed(1)}% (${file.functions.covered}/${file.functions.total})</span>
                        </div>
                    </div>
                    
                    ${file.details ? this.renderLineDetails(file.details) : ""}
                    
                    <div class="modal-actions">
                        <button class="btn btn-primary" onclick="coverageVisualizer.openFile('${file.path}')">
                            📁 Open File
                        </button>
                        <button class="btn btn-secondary" onclick="coverageVisualizer.generateTests('${file.path}')">
                            🔧 Generate Tests
                        </button>
                    </div>
                </div>
            </div>
        `;

    // Close on backdrop click
    modal.addEventListener("click", e => {
      if (e.target === modal) {
        modal.remove();
      }
    });

    return modal;
  }

  // Render line-by-line coverage details
  renderLineDetails(details) {
    if (!details.lines || details.lines.length === 0) {
      return "";
    }

    let html = '<div class="line-details"><h4>Line Coverage Details</h4><div class="line-list">';

    details.lines.forEach(line => {
      const className = line.executed ? "covered" : "uncovered";
      html += `
                <div class="line-item ${className}">
                    <span class="line-number">${line.number}</span>
                    <span class="line-content">${this.escapeHtml(line.content)}</span>
                    <span class="execution-count">${line.executed ? `×${line.count}` : "×0"}</span>
                </div>
            `;
    });

    html += "</div></div>";
    return html;
  }

  // Utility methods
  getCoverageClass(coverage) {
    if (coverage >= this.config.thresholds.high) {
      return "high";
    }
    if (coverage >= this.config.thresholds.medium) {
      return "medium";
    }
    return "low";
  }

  shortenPath(path) {
    const parts = path.split("/");
    if (parts.length <= 2) {
      return path;
    }
    return ".../" + parts.slice(-2).join("/");
  }

  escapeHtml(text) {
    const div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  }

  // Actions
  openFile(filePath) {
    // In a real implementation, this would open the file in an editor
    alert(`Opening file: ${filePath}`);
  }

  generateTests(filePath) {
    // In a real implementation, this would trigger test generation
    alert(`Generating tests for: ${filePath}`);
  }

  // Update data and refresh visualizations
  updateData(newData) {
    this.data = newData;
    this.init(newData);
  }

  // Export coverage data
  exportData(format = "json") {
    const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
    const filename = `coverage-data-${timestamp}.${format}`;

    let content;
    if (format === "json") {
      content = JSON.stringify(this.data, null, 2);
    } else if (format === "csv") {
      content = this.convertToCSV();
    }

    const blob = new Blob([content], { type: `text/${format}` });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = filename;
    a.click();
    URL.revokeObjectURL(url);
  }

  convertToCSV() {
    if (!this.data || !this.data.files) {
      return "";
    }

    const headers = [
      "File Path",
      "Line Coverage %",
      "Lines Covered",
      "Total Lines",
      "Function Coverage %",
      "Functions Covered",
      "Total Functions",
    ];
    const rows = [headers.join(",")];

    this.data.files.forEach(file => {
      rows.push(
        [
          `"${file.path}"`,
          file.lines.percentage.toFixed(2),
          file.lines.covered,
          file.lines.total,
          file.functions.percentage.toFixed(2),
          file.functions.covered,
          file.functions.total,
        ].join(","),
      );
    });

    return rows.join("\n");
  }

  // Destroy all charts
  destroy() {
    this.charts.forEach(chart => chart.destroy());
    this.charts.clear();
  }
}

// Create global instance
const _coverageVisualizer = new CoverageVisualizer();

// Auto-initialize when DOM is loaded
document.addEventListener("DOMContentLoaded", () => {
  // The dashboard will call coverageVisualizer.init() with data
});
