/**
 * Al Ijadah Smart Pickup - Free Google Apps Script Email Relay
 * 
 * Instructions:
 * 1. Open https://script.google.com while signed in to alijadahinternational@gmail.com
 * 2. Click "New Project" (rename it to "Al Ijadah Email Relay")
 * 3. Replace all existing text with this exact code.
 * 4. Click "Deploy" (top right) -> "New deployment"
 * 5. Click the gear icon (Select type) -> "Web app"
 * 6. Set Description: "Al Ijadah Web Email Relay"
 * 7. Set "Execute as": "Me (alijadahinternational@gmail.com)"
 * 8. Set "Who has access": "Anyone"
 * 9. Click "Deploy" (Grant permissions when prompted)
 * 10. Copy the "Web App URL" (e.g. https://script.google.com/macros/s/.../exec)
 * 11. Paste it into the app's Settings -> "Web / PWA Email Gateway URL" and click Save!
 */

function doPost(e) {
  try {
    var data = JSON.parse(e.postData.contents);
    var recipient = data.recipient || data.to || "alijadahinternational@gmail.com";
    var subject = data.subject || "Al Ijadah Pickup Pass Notification";
    var htmlContent = data.html || data.htmlContent || data.message || "";
    var senderName = data.senderName || "Al Ijadah International School";

    MailApp.sendEmail({
      to: recipient,
      subject: subject,
      htmlBody: htmlContent,
      name: senderName
    });

    return ContentService
      .createTextOutput(JSON.stringify({ success: true, message: "Email sent successfully" }))
      .setMimeType(ContentService.MimeType.JSON);
  } catch (err) {
    return ContentService
      .createTextOutput(JSON.stringify({ success: false, error: err.toString() }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}

function doGet(e) {
  return ContentService
    .createTextOutput(JSON.stringify({ status: "online", service: "Al Ijadah Email Relay" }))
    .setMimeType(ContentService.MimeType.JSON);
}
