use starknet::ContractAddress;

#[starknet::interface]
pub trait IArticleRegistry<TContractState> {
    fn store_article(
        ref self: TContractState, 
        title: felt252, 
        author: felt252, 
        content: felt252, 
        categories: felt252, 
        metadata: felt252, 
        date: felt252, 
        status: felt252
    );
    fn get_article(self: @TContractState, address: ContractAddress) -> Article;
    fn get_owner(self: @TContractState) -> Person;
}

#[starknet::contract]
mod ArticleRegistry {
    use starknet::{ContractAddress, get_caller_address, storage_access::StorageBaseAddress};

    #[storage]
    struct Storage {
        articles: LegacyMap::<ContractAddress, Article>,
        owner: Person,
        total_articles: u128,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        StoredArticle: StoredArticle,
    }
    #[derive(Drop, starknet::Event)]
    struct StoredArticle {
        #[key]
        user: ContractAddress,
        title: felt252,
    }

    #[derive(Drop, Serde, starknet::Store)]
    pub struct Person {
        address: ContractAddress,
        name: felt252,
    }

    #[derive(Drop, Serde, starknet::Store)]
    pub struct Article {
        title: felt252,
        author: felt252,
        content: felt252,
        categories: felt252,
        metadata: felt252,
        date: felt252,
        status: felt252,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: Person) {
        self.total_articles.write(0);
        self.owner.write(owner);
    }

    #[abi(embed_v0)]
    impl ArticleRegistry of super::IArticleRegistry<ContractState> {
        fn store_article(
            ref self: ContractState, 
            title: felt252, 
            author: felt252, 
            content: felt252, 
            categories: felt252, 
            metadata: felt252, 
            date: felt252, 
            status: felt252
        ) {
            let caller = get_caller_address();
            let article = Article {
                title,
                author,
                content,
                categories,
                metadata,
                date,
                status,
            };
            self._store_article(caller, article);
        }

        fn get_article(self: @ContractState, address: ContractAddress) -> Article {
            self.articles.read(address)
        }

        fn get_owner(self: @ContractState) -> Person {
            self.owner.read()
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _store_article(
            ref self: ContractState,
            user: ContractAddress,
            article: Article
        ) {
            let total_articles = self.total_articles.read();
            self.articles.write(user, article);
            self.total_articles.write(total_articles + 1);
            self.emit(StoredArticle { user: user, title: article.title });
        }
    }

    fn get_owner_storage_address(self: @ContractState) -> StorageBaseAddress {
        self.owner.address()
    }
}