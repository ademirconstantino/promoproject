package it.constantinoit.promoproject.service;

import it.constantinoit.promoproject.exeption.MailFailureException;
import it.constantinoit.promoproject.helper.MailHelper;
import it.constantinoit.promoproject.model.Prospect;
import it.constantinoit.promoproject.repository.ProspectRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import javax.mail.*;
import javax.mail.internet.InternetAddress;
import javax.mail.internet.MimeMessage;
import java.util.Properties;

@Service
public class EmailService {

    private static Logger LOG = LoggerFactory.getLogger(EmailService.class);

    @Autowired
    private MailHelper mailHelper;

    @Autowired
    private ProspectRepository prospectRepository;

    public Boolean sendEmail(Prospect prospect) throws MailFailureException {

        Properties properties = System.getProperties();
        properties.setProperty("mail.smtp.host", mailHelper.getHostname());
        properties.setProperty("mail.smtp.port", mailHelper.getPort());

        properties.setProperty("mail.smtp.starttls.enable", "true");
        properties.setProperty("mail.smtp.auth", "true");
        properties.setProperty("mail.smtp.socketFactory.class", "javax.net.ssl.SSLSocketFactory");
        Session session = Session.getDefaultInstance(properties,
                new javax.mail.Authenticator() {

                    protected PasswordAuthentication
                    getPasswordAuthentication() {
                        return new PasswordAuthentication(mailHelper.getUsermame(),
                                mailHelper.getPassword());
                    }
        });

        try {
            MimeMessage message = new MimeMessage(session);
            message.setFrom(new InternetAddress(mailHelper.getMailsender()));
            message.addRecipient(Message.RecipientType.TO, new InternetAddress(prospect.getEmail()));
            message.setSubject(mailHelper.getMessageSubject());
            message.setText(mailHelper.getMessage());
            Transport.send(message);

        } catch (MessagingException mex) {
            LOG.error(mex.toString());
        }

        LOG.info("send email and saved prospect: " + prospect.getEmail() + " with mongodb");
        prospectRepository.save(prospect);
        return Boolean.TRUE;
    }
}
