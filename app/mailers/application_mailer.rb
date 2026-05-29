class ApplicationMailer < ActionMailer::Base
  default from: "no-reply@flowbridge.local"
  layout "mailer"
end
