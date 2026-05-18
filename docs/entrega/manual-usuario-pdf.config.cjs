const path = require('path');

module.exports = {
  basedir: path.resolve(__dirname),
  stylesheet: [path.resolve(__dirname, 'manual-usuario-pdf.css')],
  document_title: 'Manual de Usuario NavalGO',
  pdf_options: {
    format: 'A4',
    printBackground: false,
    displayHeaderFooter: true,
    margin: {
      top: '18mm',
      right: '14mm',
      bottom: '20mm',
      left: '14mm',
    },
    headerTemplate: '<div></div>',
    footerTemplate:
      '<div style="width:100%;font-size:8px;color:#5f7284;padding:0 12mm;display:flex;justify-content:space-between;"><span>Manual de Usuario NavalGO</span><span><span class="pageNumber"></span> / <span class="totalPages"></span></span></div>',
  },
};
