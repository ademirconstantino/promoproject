package it.constantinoit.promoproject.service;

import it.constantinoit.promoproject.exeption.MailFailureException;
import it.constantinoit.promoproject.helper.MailHelper;
import it.constantinoit.promoproject.model.Prospect;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import javax.mail.Message;
import javax.mail.MessagingException;
import javax.mail.Session;
import javax.mail.Transport;
import javax.mail.internet.InternetAddress;
import javax.mail.internet.MimeMessage;
import java.util.Properties;

@Service
public class EmailService {

    @Autowired
    private MailHelper mailHelper;

    public Boolean sendEmail(Prospect prospect) throws MailFailureException {

        Properties properties = System.getProperties();
        properties.setProperty("mail.smtp.host", mailHelper.getHostname());
        Session session = Session.getDefaultInstance(properties);

        try {
            MimeMessage message = new MimeMessage(session);
            message.setFrom(new InternetAddress(mailHelper.getMailsender()));
            message.addRecipient(Message.RecipientType.TO, new InternetAddress(prospect.getEmail()));
            message.setSubject(mailHelper.getMessageSubject());
            message.setText(mailHelper.getMessage());
            Transport.send(message);
            return Boolean.TRUE;

        } catch (MessagingException mex) {
            throw new MailFailureException("Cannot send email");
        }

    }
}
