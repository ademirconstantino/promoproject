package it.constantinoit.promoproject.controller;

import it.constantinoit.promoproject.exeption.MailFailureException;
import it.constantinoit.promoproject.model.Prospect;
import it.constantinoit.promoproject.model.response.ResponsePostmail;
import it.constantinoit.promoproject.service.EmailService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.util.Date;

@RestController
public class EmailController {

    private static Logger LOG = LoggerFactory.getLogger(EmailController.class);

    @Autowired
    private EmailService emailService;

    @PostMapping(value = "/postmail", consumes = "application/json", produces = "application/json")
    public ResponsePostmail postmail(@RequestBody Prospect target) {
        try {

            emailService.sendEmail(target);
            LOG.info(" sent email to " + target.getEmail() + " regarding promos");
            return new ResponsePostmail.ResponsePostmailBuilder().
                    withEmail(target.getEmail()).
                    withDeliveryDate(new Date()).
                    withSuccess(Boolean.TRUE).build();
        } catch (MailFailureException e) {
            return new ResponsePostmail.ResponsePostmailBuilder().
                    withEmail(target.getEmail()).
                    withSuccess(Boolean.FALSE).build();
        }
    }

}
