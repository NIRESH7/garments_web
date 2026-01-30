import PDFDocument from 'pdfkit';

/**
 * Convert array of objects to PDF format
 */
export function generatePDF(data, title = 'Export') {
  return new Promise((resolve, reject) => {
    try {
      const doc = new PDFDocument({ margin: 50 });
      const chunks = [];

      // Collect PDF data
      doc.on('data', chunk => chunks.push(chunk));
      doc.on('end', () => {
        const pdfBuffer = Buffer.concat(chunks);
        resolve(pdfBuffer);
      });
      doc.on('error', reject);

      // Add title
      doc.fontSize(20)
         .font('Helvetica-Bold')
         .text(title, { align: 'center' })
         .moveDown(0.5);

      // Add date
      doc.fontSize(10)
         .font('Helvetica')
         .fillColor('gray')
         .text(`Generated on: ${new Date().toLocaleString()}`, { align: 'center' })
         .moveDown(1);

      if (!data || data.length === 0) {
        doc.fontSize(12)
           .fillColor('black')
           .text('No data available', { align: 'center' });
        doc.end();
        return;
      }

      // Get headers from first object
      const headers = Object.keys(data[0]);
      const columnCount = headers.length;
      
      // Calculate column widths (distribute evenly, max width 120)
      const pageWidth = doc.page.width - 100; // Account for margins
      const columnWidth = Math.min(120, (pageWidth - 20) / columnCount);
      const startX = 50;
      let currentY = doc.y;

      // Table header
      doc.fontSize(10)
         .font('Helvetica-Bold')
         .fillColor('white')
         .rect(startX, currentY, pageWidth, 25)
         .fill('#4F46E5'); // Indigo color

      let x = startX + 5;
      headers.forEach((header, index) => {
        const headerText = formatHeader(header);
        doc.text(headerText, x, currentY + 8, {
          width: columnWidth - 10,
          ellipsis: true
        });
        x += columnWidth;
      });

      currentY += 25;

      // Table rows
      doc.font('Helvetica')
         .fontSize(9)
         .fillColor('black');

      data.forEach((row, rowIndex) => {
        // Check if we need a new page
        if (currentY > doc.page.height - 100) {
          doc.addPage();
          currentY = 50;
          
          // Redraw header on new page
          doc.font('Helvetica-Bold')
             .fillColor('white')
             .rect(startX, currentY, pageWidth, 25)
             .fill('#4F46E5');
          
          x = startX + 5;
          headers.forEach((header) => {
            const headerText = formatHeader(header);
            doc.text(headerText, x, currentY + 8, {
              width: columnWidth - 10,
              ellipsis: true
            });
            x += columnWidth;
          });
          currentY += 25;
        }

        // Alternate row colors
        if (rowIndex % 2 === 0) {
          doc.rect(startX, currentY, pageWidth, 20)
             .fill('#F3F4F6'); // Light gray
        }

        // Row data
        x = startX + 5;
        headers.forEach((header) => {
          const value = row[header];
          const cellText = value !== null && value !== undefined ? String(value) : 'N/A';
          
          doc.fillColor('black')
             .text(cellText, x, currentY + 6, {
               width: columnWidth - 10,
               ellipsis: true
             });
          x += columnWidth;
        });

        currentY += 20;
      });

      // Add footer with page numbers
      const totalPages = doc.bufferedPageRange().count;
      for (let i = 0; i < totalPages; i++) {
        doc.switchToPage(i);
        doc.fontSize(8)
           .fillColor('gray')
           .text(
             `Page ${i + 1} of ${totalPages}`,
             doc.page.width - 100,
             doc.page.height - 30,
             { align: 'right' }
           );
      }

      doc.end();
    } catch (error) {
      reject(error);
    }
  });
}

/**
 * Format header text to be more readable
 */
function formatHeader(header) {
  // Convert snake_case to Title Case
  return header
    .split('_')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
    .join(' ');
}

