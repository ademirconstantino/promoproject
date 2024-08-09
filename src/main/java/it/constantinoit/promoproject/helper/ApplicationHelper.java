package it.constantinoit.promoproject.helper;

import lombok.Getter;
import lombok.Setter;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.PropertySource;
import org.springframework.stereotype.Component;

@Component
@PropertySource("classpath:application.properties")
@Getter
@Setter
public class ApplicationHelper {

    @Value( "${mongo.server.host}" )
    private String mongoServerHost;

    @Value( "${mongo.server.port}" )
    private String mongoServerPort;

    @Value( "${mongo.dbname}" )
    private String mongoDbName;

    @Value( "${kafka.server.host}" )
    private String KafkaServerHost;

    @Value( "${kafka.server.port}" )
    private String KafkaServerPort;

    @Value( "${kafka.server.group-id}" )
    private String kafkaGroupId;
    
}
