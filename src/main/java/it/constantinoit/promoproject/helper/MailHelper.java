package it.constantinoit.promoproject.helper;

import lombok.Getter;
import lombok.Setter;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.PropertySource;
import org.springframework.stereotype.Component;

@Component
@PropertySource("classpath:mail.properties")
@Getter
@Setter
public class MailHelper {

    @Value( "${mail.hostname}" )
    private String hostname;

    @Value( "${mail.port}" )
    private String port;

    @Value( "${mail.sender}" )
    private String mailsender;

    @Value( "${mail.subject}" )
    private String messageSubject;

    @Value( "${mail.message}" )
    private String message;

    @Value( "${mail.username}" )
    private String usermame;

    @Value( "${mail.password}" )
    private String password;

}
