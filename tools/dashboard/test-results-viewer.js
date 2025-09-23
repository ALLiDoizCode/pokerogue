/**
 * Test Results Viewer
 * Handles test result visualization and interactive test management
 */

class TestResultsViewer {
    constructor() {
        this.data = null;
        this.currentFilter = 'all';
        this.sortOrder = 'name';
        this.config = {
            refreshInterval: 30000, // 30 seconds
            maxResults: 100,
            animationDuration: 300
        };
    }

    // Initialize viewer with test results data
    init(testData) {
        this.data = testData;
        this.setupEventListeners();
        this.renderTestSummary();
        this.renderTestTable();
        this.renderTestTrends();
        this.startAutoRefresh();
    }

    // Setup event listeners for interactive features
    setupEventListeners() {
        // Filter buttons
        document.querySelectorAll('.filter-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                this.setFilter(e.target.dataset.filter);
            });
        });

        // Sort dropdown
        const sortSelect = document.getElementById('sortSelect');
        if (sortSelect) {
            sortSelect.addEventListener('change', (e) => {
                this.setSortOrder(e.target.value);
            });
        }

        // Search input
        const searchInput = document.getElementById('testSearch');
        if (searchInput) {
            searchInput.addEventListener('input', (e) => {
                this.filterTests(e.target.value);
            });
        }

        // Refresh button
        const refreshBtn = document.getElementById('refreshTests');
        if (refreshBtn) {
            refreshBtn.addEventListener('click', () => {
                this.refreshData();
            });
        }

        // Run all tests button
        const runAllBtn = document.getElementById('runAllTests');
        if (runAllBtn) {
            runAllBtn.addEventListener('click', () => {
                this.runAllTests();
            });
        }
    }

    // Render test summary cards
    renderTestSummary() {
        if (!this.data || !this.data.summary) return;

        const summary = this.data.summary;
        
        // Update summary cards
        this.updateSummaryCard('totalTests', summary.total, '📝 Total Tests');
        this.updateSummaryCard('passedTests', summary.passed, '✅ Passed', 'success');
        this.updateSummaryCard('failedTests', summary.failed, '❌ Failed', summary.failed > 0 ? 'danger' : 'success');
        this.updateSummaryCard('skippedTests', summary.skipped || 0, '⏭️ Skipped', 'warning');

        // Update pass rate
        const passRate = summary.total > 0 ? (summary.passed / summary.total * 100).toFixed(1) : 0;
        this.updateSummaryCard('passRate', `${passRate}%`, '📊 Pass Rate', passRate >= 90 ? 'success' : passRate >= 70 ? 'warning' : 'danger');

        // Update trend indicators
        this.updateTrendIndicators(summary);
    }

    // Update individual summary card
    updateSummaryCard(elementId, value, label, status = 'default') {
        const element = document.getElementById(elementId);
        if (!element) return;

        element.className = `summary-card ${status}`;
        element.innerHTML = `
            <div class="card-value">${value}</div>
            <div class="card-label">${label}</div>
        `;
    }

    // Update trend indicators
    updateTrendIndicators(summary) {
        if (!summary.trend) return;

        const indicators = ['passRate', 'totalTests', 'failedTests'];
        
        indicators.forEach(indicator => {
            const element = document.getElementById(`${indicator}Trend`);
            if (!element || !summary.trend[indicator]) return;

            const trend = summary.trend[indicator];
            const icon = trend > 0 ? '📈' : trend < 0 ? '📉' : '➡️';
            const className = trend > 0 ? 'trend-up' : trend < 0 ? 'trend-down' : 'trend-stable';
            
            element.className = `trend-indicator ${className}`;
            element.innerHTML = `${icon} ${Math.abs(trend).toFixed(1)}%`;
            element.title = `${trend > 0 ? 'Increase' : trend < 0 ? 'Decrease' : 'No change'} from last run`;
        });
    }

    // Render test results table
    renderTestTable() {
        const tableBody = document.querySelector('#testResultsTable tbody');
        if (!tableBody || !this.data || !this.data.suites) return;

        const filteredData = this.getFilteredData();
        const sortedData = this.getSortedData(filteredData);

        let tableHTML = '';

        if (sortedData.length === 0) {
            tableHTML = '<tr><td colspan="7" class="no-results">No test results match your criteria</td></tr>';
        } else {
            sortedData.forEach(suite => {
                const status = this.getTestStatus(suite);
                const duration = suite.duration ? `${suite.duration.toFixed(2)}s` : 'N/A';
                const lastRun = suite.lastRun ? this.formatTime(suite.lastRun) : 'Never';
                
                tableHTML += `
                    <tr class="test-row ${status.className}" data-suite="${suite.name}">
                        <td>
                            <div class="test-name">
                                <span class="suite-icon">${status.icon}</span>
                                <span class="suite-name">${suite.name}</span>
                            </div>
                            ${suite.description ? `<div class="suite-description">${suite.description}</div>` : ''}
                        </td>
                        <td>
                            <span class="test-type ${suite.type || 'unit'}">${suite.type || 'Unit'}</span>
                        </td>
                        <td>
                            <div class="status-cell">
                                <span class="status-indicator ${status.className}">${status.text}</span>
                                <div class="test-counts">
                                    <span class="passed">✅ ${suite.passed || 0}</span>
                                    <span class="failed">❌ ${suite.failed || 0}</span>
                                </div>
                            </div>
                        </td>
                        <td>
                            <div class="coverage-cell">
                                ${this.renderCoverageBar(suite.coverage || 0)}
                                <span class="coverage-text">${(suite.coverage || 0).toFixed(1)}%</span>
                            </div>
                        </td>
                        <td>
                            <span class="duration ${duration === 'N/A' ? 'no-data' : ''}">${duration}</span>
                        </td>
                        <td>
                            <span class="last-run">${lastRun}</span>
                        </td>
                        <td>
                            <div class="action-buttons">
                                <button class="btn-small btn-primary" onclick="testResultsViewer.runSuite('${suite.name}')" title="Run Tests">
                                    ▶️
                                </button>
                                <button class="btn-small btn-secondary" onclick="testResultsViewer.viewDetails('${suite.name}')" title="View Details">
                                    👁️
                                </button>
                                <button class="btn-small btn-info" onclick="testResultsViewer.viewLogs('${suite.name}')" title="View Logs">
                                    📋
                                </button>
                                ${suite.failed > 0 ? 
                                    `<button class="btn-small btn-warning" onclick="testResultsViewer.debugFailures('${suite.name}')" title="Debug Failures">🐛</button>` : 
                                    ''
                                }
                            </div>
                        </td>
                    </tr>
                `;
            });
        }

        tableBody.innerHTML = tableHTML;
        this.updateTableStats(sortedData);
    }

    // Render coverage progress bar
    renderCoverageBar(coverage) {
        const className = coverage >= 90 ? 'high' : coverage >= 70 ? 'medium' : 'low';
        return `
            <div class="progress-bar mini">
                <div class="progress-fill ${className}" style="width: ${coverage}%"></div>
            </div>
        `;
    }

    // Get test status information
    getTestStatus(suite) {
        const total = (suite.passed || 0) + (suite.failed || 0) + (suite.skipped || 0);
        
        if (total === 0) {
            return { icon: '⚪', text: 'No Tests', className: 'no-tests' };
        }
        
        if (suite.failed > 0) {
            return { icon: '❌', text: `${suite.failed} Failed`, className: 'failed' };
        }
        
        if (suite.skipped > 0) {
            return { icon: '⏭️', text: `${suite.skipped} Skipped`, className: 'skipped' };
        }
        
        return { icon: '✅', text: 'All Passed', className: 'passed' };
    }

    // Update table statistics
    updateTableStats(data) {
        const statsElement = document.getElementById('tableStats');
        if (!statsElement) return;

        const total = data.length;
        const passed = data.filter(suite => (suite.failed || 0) === 0).length;
        const failed = data.filter(suite => (suite.failed || 0) > 0).length;

        statsElement.innerHTML = `
            Showing ${total} test suites | 
            <span class="stat-passed">${passed} passing</span> | 
            <span class="stat-failed">${failed} failing</span>
        `;
    }

    // Render test trends chart
    renderTestTrends() {
        const canvas = document.getElementById('testTrendsChart');
        if (!canvas || !this.data || !this.data.trends) return;

        const ctx = canvas.getContext('2d');
        const trends = this.data.trends;

        const chart = new Chart(ctx, {
            type: 'line',
            data: {
                labels: trends.dates,
                datasets: [
                    {
                        label: 'Pass Rate %',
                        data: trends.passRates,
                        borderColor: '#28a745',
                        backgroundColor: 'rgba(40, 167, 69, 0.1)',
                        tension: 0.4,
                        fill: true,
                        yAxisID: 'percentage'
                    },
                    {
                        label: 'Total Tests',
                        data: trends.totalTests,
                        borderColor: '#007bff',
                        backgroundColor: 'rgba(0, 123, 255, 0.1)',
                        tension: 0.4,
                        fill: false,
                        yAxisID: 'count'
                    },
                    {
                        label: 'Failed Tests',
                        data: trends.failedTests,
                        borderColor: '#dc3545',
                        backgroundColor: 'rgba(220, 53, 69, 0.1)',
                        tension: 0.4,
                        fill: false,
                        yAxisID: 'count'
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    title: {
                        display: true,
                        text: 'Test Results Trend (30 Days)',
                        font: { size: 16, weight: 'bold' }
                    },
                    legend: {
                        position: 'top'
                    }
                },
                scales: {
                    x: {
                        title: {
                            display: true,
                            text: 'Date'
                        }
                    },
                    percentage: {
                        type: 'linear',
                        display: true,
                        position: 'left',
                        title: {
                            display: true,
                            text: 'Pass Rate (%)'
                        },
                        min: 0,
                        max: 100
                    },
                    count: {
                        type: 'linear',
                        display: true,
                        position: 'right',
                        title: {
                            display: true,
                            text: 'Test Count'
                        },
                        grid: {
                            drawOnChartArea: false
                        }
                    }
                }
            }
        });
    }

    // Filter and search functionality
    setFilter(filter) {
        this.currentFilter = filter;
        
        // Update filter button states
        document.querySelectorAll('.filter-btn').forEach(btn => {
            btn.classList.toggle('active', btn.dataset.filter === filter);
        });
        
        this.renderTestTable();
    }

    setSortOrder(order) {
        this.sortOrder = order;
        this.renderTestTable();
    }

    filterTests(searchTerm) {
        this.searchTerm = searchTerm.toLowerCase();
        this.renderTestTable();
    }

    getFilteredData() {
        if (!this.data || !this.data.suites) return [];

        let filtered = [...this.data.suites];

        // Apply status filter
        if (this.currentFilter !== 'all') {
            filtered = filtered.filter(suite => {
                switch (this.currentFilter) {
                    case 'passed':
                        return (suite.failed || 0) === 0 && (suite.passed || 0) > 0;
                    case 'failed':
                        return (suite.failed || 0) > 0;
                    case 'skipped':
                        return (suite.skipped || 0) > 0;
                    default:
                        return true;
                }
            });
        }

        // Apply search filter
        if (this.searchTerm) {
            filtered = filtered.filter(suite => 
                suite.name.toLowerCase().includes(this.searchTerm) ||
                (suite.description || '').toLowerCase().includes(this.searchTerm)
            );
        }

        return filtered;
    }

    getSortedData(data) {
        return [...data].sort((a, b) => {
            switch (this.sortOrder) {
                case 'name':
                    return a.name.localeCompare(b.name);
                case 'status':
                    return (b.failed || 0) - (a.failed || 0);
                case 'coverage':
                    return (b.coverage || 0) - (a.coverage || 0);
                case 'duration':
                    return (b.duration || 0) - (a.duration || 0);
                case 'lastRun':
                    return new Date(b.lastRun || 0) - new Date(a.lastRun || 0);
                default:
                    return 0;
            }
        });
    }

    // Test actions
    runSuite(suiteName) {
        this.showLoadingState(suiteName);
        
        // Simulate test run
        setTimeout(() => {
            this.hideLoadingState(suiteName);
            this.showNotification(`Running tests for ${suiteName}...`, 'info');
            
            // In real implementation, this would trigger actual test run
            // and update results when complete
        }, 500);
    }

    runAllTests() {
        this.showNotification('Running all tests...', 'info');
        
        // Simulate running all tests
        setTimeout(() => {
            this.showNotification('All tests completed!', 'success');
            this.refreshData();
        }, 2000);
    }

    viewDetails(suiteName) {
        const suite = this.data.suites.find(s => s.name === suiteName);
        if (!suite) return;

        this.showTestDetailsModal(suite);
    }

    viewLogs(suiteName) {
        const suite = this.data.suites.find(s => s.name === suiteName);
        if (!suite) return;

        this.showTestLogsModal(suite);
    }

    debugFailures(suiteName) {
        const suite = this.data.suites.find(s => s.name === suiteName);
        if (!suite) return;

        this.showDebugModal(suite);
    }

    // Modal functions
    showTestDetailsModal(suite) {
        const modal = document.createElement('div');
        modal.className = 'modal-overlay';
        modal.innerHTML = `
            <div class="modal-content large">
                <div class="modal-header">
                    <h3>Test Details: ${suite.name}</h3>
                    <button class="modal-close" onclick="this.closest('.modal-overlay').remove()">&times;</button>
                </div>
                <div class="modal-body">
                    <div class="test-details">
                        <div class="details-section">
                            <h4>Summary</h4>
                            <div class="detail-grid">
                                <div class="detail-item">
                                    <label>Status:</label>
                                    <span class="status ${(suite.failed || 0) > 0 ? 'failed' : 'passed'}">
                                        ${(suite.failed || 0) > 0 ? '❌ Failed' : '✅ Passed'}
                                    </span>
                                </div>
                                <div class="detail-item">
                                    <label>Duration:</label>
                                    <span>${suite.duration ? `${suite.duration.toFixed(2)}s` : 'N/A'}</span>
                                </div>
                                <div class="detail-item">
                                    <label>Coverage:</label>
                                    <span>${(suite.coverage || 0).toFixed(1)}%</span>
                                </div>
                                <div class="detail-item">
                                    <label>Tests:</label>
                                    <span>${(suite.passed || 0) + (suite.failed || 0)} total</span>
                                </div>
                            </div>
                        </div>
                        
                        ${suite.tests ? this.renderTestList(suite.tests) : ''}
                        
                        <div class="modal-actions">
                            <button class="btn btn-primary" onclick="testResultsViewer.runSuite('${suite.name}')">
                                ▶️ Run Tests
                            </button>
                            <button class="btn btn-secondary" onclick="testResultsViewer.viewLogs('${suite.name}')">
                                📋 View Logs
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        `;

        document.body.appendChild(modal);
        setTimeout(() => modal.classList.add('show'), 10);

        modal.addEventListener('click', (e) => {
            if (e.target === modal) modal.remove();
        });
    }

    renderTestList(tests) {
        if (!tests || tests.length === 0) return '';

        let html = '<div class="details-section"><h4>Individual Tests</h4><div class="test-list">';
        
        tests.forEach(test => {
            const status = test.status || 'unknown';
            const icon = status === 'passed' ? '✅' : status === 'failed' ? '❌' : '⚪';
            
            html += `
                <div class="test-item ${status}">
                    <div class="test-info">
                        <span class="test-icon">${icon}</span>
                        <span class="test-title">${test.name}</span>
                        <span class="test-duration">${test.duration ? `${test.duration}ms` : ''}</span>
                    </div>
                    ${test.error ? `<div class="test-error">${test.error}</div>` : ''}
                </div>
            `;
        });
        
        html += '</div></div>';
        return html;
    }

    // Utility functions
    showLoadingState(suiteName) {
        const row = document.querySelector(`tr[data-suite="${suiteName}"]`);
        if (row) {
            row.classList.add('loading');
        }
    }

    hideLoadingState(suiteName) {
        const row = document.querySelector(`tr[data-suite="${suiteName}"]`);
        if (row) {
            row.classList.remove('loading');
        }
    }

    showNotification(message, type = 'info') {
        const notification = document.createElement('div');
        notification.className = `notification ${type}`;
        notification.innerHTML = `
            <span class="notification-message">${message}</span>
            <button class="notification-close" onclick="this.parentElement.remove()">&times;</button>
        `;

        document.body.appendChild(notification);
        
        setTimeout(() => {
            notification.classList.add('show');
        }, 10);

        setTimeout(() => {
            if (notification.parentElement) {
                notification.remove();
            }
        }, 5000);
    }

    formatTime(timestamp) {
        const date = new Date(timestamp);
        const now = new Date();
        const diffMs = now - date;
        const diffMins = Math.floor(diffMs / 60000);
        const diffHours = Math.floor(diffMs / 3600000);
        const diffDays = Math.floor(diffMs / 86400000);

        if (diffMins < 1) return 'Just now';
        if (diffMins < 60) return `${diffMins}m ago`;
        if (diffHours < 24) return `${diffHours}h ago`;
        if (diffDays < 7) return `${diffDays}d ago`;
        return date.toLocaleDateString();
    }

    // Auto-refresh functionality
    startAutoRefresh() {
        if (this.refreshTimer) {
            clearInterval(this.refreshTimer);
        }

        this.refreshTimer = setInterval(() => {
            this.refreshData();
        }, this.config.refreshInterval);
    }

    async refreshData() {
        try {
            // In real implementation, this would fetch fresh data
            this.showNotification('Refreshing test data...', 'info');
            
            // Simulate data refresh
            setTimeout(() => {
                this.showNotification('Test data refreshed', 'success');
            }, 1000);
        } catch (error) {
            this.showNotification('Failed to refresh test data', 'error');
        }
    }

    // Update with new data
    updateData(newData) {
        this.data = newData;
        this.renderTestSummary();
        this.renderTestTable();
        this.renderTestTrends();
    }

    // Cleanup
    destroy() {
        if (this.refreshTimer) {
            clearInterval(this.refreshTimer);
        }
    }
}

// Create global instance
const testResultsViewer = new TestResultsViewer();

// Auto-initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    // The dashboard will call testResultsViewer.init() with data
});