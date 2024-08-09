package it.constantinoit.promoproject.config;

import com.mongodb.ConnectionString;
import com.mongodb.MongoClientSettings;
import com.mongodb.client.MongoClient;
import com.mongodb.client.MongoClients;
import it.constantinoit.promoproject.helper.ApplicationHelper;
import it.constantinoit.promoproject.kafka.consumer.MessageConsumer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.convert.converter.Converter;
import org.springframework.data.mongodb.config.AbstractMongoClientConfiguration;
import org.springframework.data.mongodb.repository.config.EnableMongoRepositories;

import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.List;

@Configuration
@EnableMongoRepositories(basePackages = "it.constantinoit.promoproject.repository")
public class MongoConfig extends AbstractMongoClientConfiguration {

    private static final Logger LOG = LoggerFactory.getLogger(MongoConfig.class);

    @Autowired
    private ApplicationHelper applicationHelper;

    private final List<Converter<?, ?>> converters = new ArrayList<Converter<?, ?>>();

    @Override
    protected String getDatabaseName() {
        return "promoproject";
    }

    @Override
    public MongoClient mongoClient() {

        LOG.info("Setting up mongoDB");

        String mongoServer = applicationHelper.getMongoServerHost();
        String mongoPort = applicationHelper.getMongoServerPort();
        String dbnName = applicationHelper.getMongoDbName();

        final ConnectionString connectionString = new ConnectionString(String.format("mongodb://%s:%s/%s"
                ,mongoServer, mongoPort, dbnName));

        LOG.info("Setting up mongoDB: connectionString {}", connectionString);

        final MongoClientSettings mongoClientSettings = MongoClientSettings.builder()
                .applyConnectionString(connectionString)
                .build();
        return MongoClients.create(mongoClientSettings);
    }

    @Override
    public Collection<String> getMappingBasePackages() {
        return Collections.singleton("it.constantinoit.promoproject");
    }

}