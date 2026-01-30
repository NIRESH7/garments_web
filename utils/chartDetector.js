/**
 * Utility functions to detect if data is suitable for chart visualization
 */

/**
 * Check if data is suitable for pie chart (categorical data with counts)
 */
export function isSuitableForPieChart(data) {
  if (!data || data.length === 0) return false;
  
  // Check if data has 2 columns (category and count/value)
  const keys = Object.keys(data[0]);
  if (keys.length !== 2) return false;
  
  // Check if one column is numeric (count/value) and other is categorical
  const [col1, col2] = keys;
  const col1Values = data.map(row => row[col1]);
  const col2Values = data.map(row => row[col2]);
  
  const col1IsNumeric = col1Values.every(val => !isNaN(parseFloat(val)) && isFinite(val));
  const col2IsNumeric = col2Values.every(val => !isNaN(parseFloat(val)) && isFinite(val));
  
  // One should be numeric (count), other should be categorical
  if (col1IsNumeric && !col2IsNumeric) {
    return { suitable: true, categoryKey: col2, valueKey: col1 };
  }
  if (col2IsNumeric && !col1IsNumeric) {
    return { suitable: true, categoryKey: col1, valueKey: col2 };
  }
  
  return false;
}

/**
 * Check if data is suitable for bar chart (categorical vs numeric)
 */
export function isSuitableForBarChart(data) {
  if (!data || data.length === 0) return false;
  
  const keys = Object.keys(data[0]);
  if (keys.length < 2) return false;
  
  // Find categorical and numeric columns
  const categoricalKeys = [];
  const numericKeys = [];
  
  keys.forEach(key => {
    const values = data.map(row => row[key]);
    const allNumeric = values.every(val => !isNaN(parseFloat(val)) && isFinite(val) && val !== null && val !== '');
    const allCategorical = values.every(val => val === null || val === '' || (!isNaN(parseFloat(val)) === false));
    
    if (allNumeric && values.length > 0) {
      numericKeys.push(key);
    } else if (!allNumeric) {
      categoricalKeys.push(key);
    }
  });
  
  if (categoricalKeys.length > 0 && numericKeys.length > 0) {
    return {
      suitable: true,
      categoryKey: categoricalKeys[0],
      valueKey: numericKeys[0]
    };
  }
  
  return false;
}

/**
 * Detect chart type based on data and query
 */
export function detectChartType(data, query = '') {
  const queryLower = query.toLowerCase();
  
  // Check for distribution/count queries (pie chart)
  const distributionKeywords = ['distribution', 'count', 'total', 'by', 'gender', 'class', 'section', 'type', 'category'];
  const isDistributionQuery = distributionKeywords.some(keyword => queryLower.includes(keyword));
  
  if (isDistributionQuery) {
    const pieChart = isSuitableForPieChart(data);
    if (pieChart) {
      return { type: 'pie', ...pieChart };
    }
  }
  
  // Check for comparison queries (bar chart)
  const comparisonKeywords = ['compare', 'comparison', 'average', 'sum', 'total', 'marks', 'attendance', 'fees'];
  const isComparisonQuery = comparisonKeywords.some(keyword => queryLower.includes(keyword));
  
  if (isComparisonQuery) {
    const barChart = isSuitableForBarChart(data);
    if (barChart) {
      return { type: 'bar', ...barChart };
    }
  }
  
  // Default: try pie chart if suitable
  const pieChart = isSuitableForPieChart(data);
  if (pieChart) {
    return { type: 'pie', ...pieChart };
  }
  
  // Try bar chart
  const barChart = isSuitableForBarChart(data);
  if (barChart) {
    return { type: 'bar', ...barChart };
  }
  
  return null;
}

/**
 * Prepare data for chart
 */
export function prepareChartData(data, categoryKey, valueKey) {
  const labels = data.map(row => {
    const value = row[categoryKey];
    return value !== null && value !== undefined ? String(value) : 'N/A';
  });
  
  const values = data.map(row => {
    const value = row[valueKey];
    return value !== null && value !== undefined ? parseFloat(value) || 0 : 0;
  });
  
  return { labels, values };
}

