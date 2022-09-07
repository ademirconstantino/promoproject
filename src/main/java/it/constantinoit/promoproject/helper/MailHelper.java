package it.constantinoit.promoproject.helper;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.PropertySource;
import org.springframework.stereotype.Component;

@Component
@PropertySource("classpath:mail.properties")
public class MailHelper {

    @Value( "${mail.hostname}" )
    private String hostname;

    @Value( "${mail.sender}" )
    private String mailsender;

    @Value( "${mail.subject}" )
    private String messageSubject;

    @Value( "${mail.message}" )
    private String message;

    public String getHostname() {
        return hostname;
    }

    public void setHostname(String hostname) {
        this.hostname = hostname;
    }

    public String getMailsender() {
        return mailsender;
    }

    public void setMailsender(String mailsender) {
        this.mailsender = mailsender;
    }

    public String getMessageSubject() {
        return messageSubject;
    }

    public void setMessageSubject(String messageSubject) {
        this.messageSubject = messageSubject;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }
}
