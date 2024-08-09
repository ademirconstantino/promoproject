package it.constantinoit.promoproject.events;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import it.constantinoit.promoproject.exeption.MailFailureException;
import it.constantinoit.promoproject.model.Prospect;
import it.constantinoit.promoproject.service.EmailService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.io.IOException;

@Service
@SuppressWarnings("all")
public class PostmailEventHandler {

    private static final Logger LOG = LoggerFactory.getLogger(PostmailEventHandler.class);

    @Autowired
    private EmailService emailService;

    public void receiveEventPostmail(String message) throws JsonProcessingException {
        LOG.info("Receiving message {} and hadling event PostmailEventHandler.receiveEventPostmail() ", message);

        try {
            ObjectMapper mapper = new ObjectMapper();
            Prospect prospect = mapper.readValue(message, Prospect.class);
            emailService.sendEmail(prospect);

        } catch (IOException | MailFailureException ex) {
            LOG.error("Exception at PostmailEventHandler.receiveEventPostmail: {}", ex);
        }
    }

}
